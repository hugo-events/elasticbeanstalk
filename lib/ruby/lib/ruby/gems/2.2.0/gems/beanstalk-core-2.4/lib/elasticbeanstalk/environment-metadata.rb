
#==============================================================================
# Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#       https://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#==============================================================================

require 'fileutils'
require 'json'
require 'logger'
require 'open-uri'

require 'elasticbeanstalk/cfn-wrapper'
require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/utils'

module ElasticBeanstalk
    class EnvironmentMetadata
        @@config_path = '/etc/elasticbeanstalk/.aws-eb-stack.properties'
        @@metadata_cache_path = '/etc/elasticbeanstalk/metadata-cache'
        REQUEST_ID_KEY = 'request_id'
        METADATA_KEY = 'metadata'
        TIMESTAMP_KEY = 'timestamp'

        INITIAL_REQUEST_ID = '0' # by convention 0 means the first retrieve

        attr_reader :environment_id, :environment_bucket, :stack_name, :resource, :region, :cfn_url

        def initialize(config_file: @@config_path, cache_file: @@metadata_cache_path, logger: Logger.new(File.open(File::NULL, "w")))
            @logger = logger
            @cache_file = cache_file
            @config_file = config_file
            read_config_file

            @region = @configs['region']
            @stack_name = @configs['stack_name']
            @resource = @configs['resource']
            @environment_id = @configs['environment_id']
            @environment_bucket = @configs['environment_bucket']
            @cfn_url = @configs['cfn_url']

            if !(@region && @stack_name && @resource && @environment_id && @environment_bucket)
                @logger.error("Not all of the stack properties are found!")
                raise BeanstalkRuntimeError, %[Not all of the stack properties are found!]
            end

            FileUtils.mkdir_p(File.dirname(@cache_file))
        end

        def stack_name=(value)
            @configs['stack_name'] = @stack_name = value
        end

        def app_source_url
            metadata(path: "AWS::ElasticBeanstalk::Ext||_AppSourceUrlFileContent||url")
        end
        
        def container_config
            metadata(path: "AWS::ElasticBeanstalk::Ext||_ContainerConfigFileContent")
        end

        def command_definitions
            metadata(path: "AWS::ElasticBeanstalk::Ext||_ContainerConfigFileContent||commands")
        end

        def launch_s3_url
            metadata(path: "AWS::ElasticBeanstalk::Ext||_LaunchS3URL")
        end

        def instance_signal_url
            metadata(path: "AWS::ElasticBeanstalk::Ext||InstanceSignalURL", default: '')
        end

        def manifest_s3_key
            metadata(path: 'AWS::ElasticBeanstalk::Ext||ManifestFileS3Key', raise_if_not_exist: false)
        end

        def ebextension_file_paths
            metadata(path: "AWS::ElasticBeanstalk::Ext||_EBExtensionFilePaths", default: {})
        end

        def environment_stack_id
            metadata(path: 'AWS::ElasticBeanstalk::Ext||EnvironmentStackId')
        end

        def instance_profile_specified?
            if metadata(path: 'AWS::CloudFormation::Init||Infra-WriteApplication2||files', raise_if_not_exist: false)
                true
            else
                false
            end
        end

        def instance_id
            @instance_id ||= HttpUtils.download(source_uri: 'http://169.254.169.254/latest/meta-data/instance-id')
        end

        def command_config_sets(cmd_data)
            @logger.info("Retrieving configsets for command #{cmd_data.command_name}..")
            begin
                cmd_metadata = metadata(path: "AWS::ElasticBeanstalk::Ext||_API||_Commands||#{cmd_data.command_name}||_Stages")
            rescue
                msg = "Invalid command name or stage name. Cannot retrieve configsets! for command #{cmd_data.command_name}"
                @logger.error(msg)
                raise BeanstalkRuntimeError, msg
            end
            if cmd_data.stage_name
                cmd_stages = [cmd_data.stage_name]
            else
                cmd_stages = cmd_metadata.keys.sort
            end
            cmd_stages.collect { |stage| cmd_metadata[stage] }.flatten
        end
        
        def leader?(cmd_data)
            @logger.info('Running leader election...')

            error_msg = nil
            2.times do
                begin
                    result = CfnWrapper.elect_cmd_leader(cmd_name: cmd_data.cfn_command_name,
                                                         invocation_id: cmd_data.invocation_id,
                                                         instance_id: instance_id,
                                                         env_metadata: self, raise_on_error: false)
                    exitstatus = result.exitstatus
                    if exitstatus == 0
                        @logger.info("Instance is Leader.")
                        return true
                    elsif exitstatus == 5
                        @logger.info("Instance is NOT Leader.")
                        return false
                    else
                        error_msg = "#{result} with return code = #{exitstatus.to_s}"
                    end
                rescue Exception => e
                    error_msg = e.message
                end
            end
            @logger.error("Failed to elect command leader: #{error_msg}")
            raise BeanstalkRuntimeError, %[Failed to elect command leader: #{error_msg}]

        end

        def refresh(request_id:, resource: nil)
            resource = @resource if resource.nil? || resource.strip.empty?
            refresh_metadata(request_id, resource)
        end

        # default value cannot be nil
        def metadata(path:, delimiter: '||', default: nil, raise_if_not_exist: true)
            @logger.debug("Retrieving metadata for key: #{path}..")

            if ! File.exist?(@cache_file)
                # Retrieve metadata if cache not exists
                refresh(request_id: INITIAL_REQUEST_ID)
            end

            begin
                metadata = JSON.parse(File.read(@cache_file)).fetch(METADATA_KEY)
            rescue Exception => e
                @logger.error("Error reading metadata: #{e.message}")
                raise e
            end

            path.split(delimiter).each do |subkey|
                if metadata.has_key?(subkey)
                    metadata = metadata[subkey]
                else
                    if default.nil? && raise_if_not_exist
                        @logger.info("Path #{path} does not exist in metadata")
                        raise BeanstalkRuntimeError, %[Path #{path} doesn't exist in metadata.]
                    else
                        metadata = default
                        break
                    end
                end
            end

            metadata
        end

        def write_config_file
            FileUtils.mkdir_p(File.dirname(@config_file))
            IO.write(@config_file, @configs.map { |k,v| "#{k}=#{v}" }.join("\n"))
        end

        def clear_metadata_cache
            FileUtils.rm_f @cache_file
        end

        #
        # Private methods
        #
        private
        def read_config_file
            @logger.debug("Reading config file: #{@config_file}")
            if !File.exists?(@config_file)
                @logger.error("Config file missing: #{@config_file}")
                raise BeanstalkRuntimeError, %[Config file missing: #{@config_file}!]
            end
            @configs = {}
            raw = File.readlines(@config_file).each do |line|
                match_results = /^([^#].*)=(.+)$/.match(line)

                if !match_results.nil?
                    @configs[match_results[1]] = match_results[2]
                end
            end
            @configs
        end

        private
        def refresh_metadata(request_id, resource)
            @logger.debug('Refreshing metadata...')

            begin
                cache = JSON.parse(File.read(@cache_file))
                cached_request_id = cache.fetch(REQUEST_ID_KEY)
                metadata = cache.fetch(METADATA_KEY)
            rescue Exception => e
                # if we cannot read cache file or cannot read request_id from cache, then consider it not exist
                cache = nil
            end

            # if cache doesn't exist or cached request_id doesn't match, then refresh
            if cache.nil? || cached_request_id != request_id
                result = CfnWrapper.resource_metadata(env_metadata: self, resource: resource)
                metadata = JSON.parse(result)
                cache = {REQUEST_ID_KEY => request_id,
                         TIMESTAMP_KEY => (Time.now.to_f*1000).to_i,    # epoch time in ms
                         METADATA_KEY => metadata}
                File.open(@cache_file, 'w') { |f| f.write(cache.to_json) }
                File.chmod(0600, @cache_file)
                @logger.debug('Refreshed environment metadata.')
            else
                @logger.debug('Using cached environment metadata.')
            end

            metadata
        end
    end
end
