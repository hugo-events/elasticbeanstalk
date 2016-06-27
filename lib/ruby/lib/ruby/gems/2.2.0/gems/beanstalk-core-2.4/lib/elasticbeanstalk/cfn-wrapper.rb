
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

require 'shellwords'
require 'time'

require 'executor'
require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/utils'


module ElasticBeanstalk

    class CfnWrapper
        @@cfn_init_output_regex = /Error occurred during build: (.+)/
        @@cfn_cmd_failed_regex = /Command (\S+) failed/
        @@cfn_yum_failed_regex = /([yY]um .+|Could not .+ yum packages)/

        @@prebuild_config_regex = /prebuild_\d+_.+/
        @@postbuild_config_regex = /postbuild_\d+_.+/

        @@cfn_hup_conf_path = '/etc/cfn/cfn-hup.conf'

        # There are only four cases we run configset: prebuild, postbuild, writeapplication2, and specified in command.
        def self.run_config_sets(config_sets:, env_metadata: nil, isEbExtension: false)
            env_metadata ||= EnvironmentMetadata.new
            call = "/opt/aws/bin/cfn-init -s '#{env_metadata.stack_name}' -r '#{env_metadata.resource}' --region '#{env_metadata.region}' --configsets '#{config_sets}'"

            start_time = self.current_time
            ex = nil
            begin
                result = self.call_cfn_script(call, env_metadata, print_cmd_on_error: false)
            rescue => ex
            end

            entries, failed_key, failed_config, _ = CfnCmdLogParser.parse(start_time)
            # recompile exception object if it's external error
            if ex && ex.is_a?(Executor::NonZeroExitStatus)
                ex = self.recompile_exception(env_metadata: env_metadata, isEbExtension: isEbExtension,
                                             failed_key: failed_key, failed_config: failed_config, ex: ex)
            end

            # generate log for activities, and raise exception when matches
            self.generate_activity_log(entries: entries, failed_key: failed_key, ex: ex)

            raise ex if ex  # if no entry is read
            result
        end

        def self.update_cfn_hup_conf(stack_name: nil, url: nil, file_path: @@cfn_hup_conf_path)
            content = File.read(file_path)
            content.gsub!(/^stack=\S+$/, "stack=#{stack_name}") if stack_name
            content.gsub!(/^url=\S+$/, "url=#{url}") if url
            File.write(file_path, content)
            FileUtils.chmod(0400, file_path)
            FileUtils.chown('root', 'root', file_path)
        end

        def self.resource_metadata(resource:, env_metadata:)
            metadata_call = "/opt/aws/bin/cfn-get-metadata --region='#{env_metadata.region}' --stack='#{env_metadata.stack_name}' --resource='#{resource}'"
            self.call_cfn_script(metadata_call, env_metadata)
        end


        def self.send_cmd_event(payload:, env_metadata:, escape_payload: true)
            if escape_payload
                payload = Shellwords.escape(payload)
            end
            call = "/opt/aws/bin/cfn-send-cmd-event #{payload}"
            self.call_cfn_script(call, env_metadata, env: ENV)
        end


        def self.elect_cmd_leader(cmd_name:, invocation_id:, instance_id:, env_metadata:, raise_on_error:)
            call = "/opt/aws/bin/cfn-elect-cmd-leader --stack '#{env_metadata.stack_name}' --command-name '#{cmd_name}' --invocation-id '#{invocation_id}' --listener-id '#{instance_id}' --region='#{env_metadata.region}'"
            self.call_cfn_script(call, env_metadata, raise_on_error: raise_on_error)
        end


        ##------------ private helpers ---------------

        def self.call_cfn_script (call, env_metadata, *args)
            call = "#{call} --url #{env_metadata.cfn_url}" if env_metadata.cfn_url
            result = Executor::Exec.sh(call, *args)
        end


        def self.recompile_exception(env_metadata:, isEbExtension:, failed_key:, failed_config:, ex:)
            ret = ex
            exit_code = ex.exit_code
            failure = Utils.extract_string(string: ex.message, regex: @@cfn_init_output_regex)
            config_name = failed_config.nil? ? '' : failed_config.name

            if isEbExtension
                prebuild = config_name.match(@@prebuild_config_regex)   # detect is it prebuild or postbuild
                ebext_file_name = env_metadata.ebextension_file_paths[config_name]  #

                case failure
                    when failed_key && @@cfn_cmd_failed_regex
                        name = prebuild ? "command #{$1}" : "container_command #{$1}"
                        ret = ExternalInvocationError.new(
                            reason: ebext_file_name ? "#{name} in #{ebext_file_name} failed." : "EBExtension #{name} failed.",
                            output: 'Command ' + $1 == failed_key.name ? failed_key.output : '',
                            exit_code: failed_key.exit_code.nil? ? 1 : failed_key.exit_code
                        )
                    when @@cfn_yum_failed_regex
                        # is yum failure
                        ret = ExternalInvocationError.new(
                            reason: "Package listed in #{ebext_file_name ? ebext_file_name : 'EBExtension'} failed to install.",
                            output: (failed_key && failed_key.output && failed_key.output.length > 0) ? failed_key.output : failure,
                            exit_code: exit_code
                        )
                    else
                        # is generic failure
                        ret = ExternalInvocationError.new(
                            reason: "EBExtension #{ebext_file_name ? 'in ' + ebext_file_name + ' ': ''}failed.",
                            output: failure.nil? ? ex.message : failure,
                            exit_code: exit_code
                        )
                end
            else
                ret = ExternalInvocationError.new(
                    reason: 'Command failed.',
                    output: failure.nil? ? ex.message : failure,
                    exit_code: exit_code
                )
            end
            ret
        end


        # recursively generate activity logs
        def self.generate_activity_log(entries:, failed_key:, ex:, root_activity: true)
            (entries.length - 1).downto(0) do |index|
                entry = entries[index]
                Activity.create(name: entry.name, start_time: entry.start_timestamp, end_time: entry.end_timestamp) do
                    if entry.collections && ! entry.collections.empty?
                        generate_activity_log(entries: entry.collections, failed_key: failed_key,
                                              ex: ex, root_activity: false)
                    end

                    # if command failed, and command name matches or this is the very last entry, raise exception
                    if ex && (entry == failed_key || root_activity && index == 0)
                        raise ex
                    else
                        entry.output
                    end
                end
            end
        end


        def self.current_time
            Time.now
        end


        class CfnCmdLogParser
            class Collection
                attr_accessor :name, :collections, :exit_code, :output, :start_timestamp, :end_timestamp
                def initialize(name:, collections: [], exit_code: nil, output: '', start_timestamp: nil, end_timestamp: nil)
                    @name = name
                    @collections = collections
                    @exit_code = exit_code
                    @output = output
                    @start_timestamp = start_timestamp
                    @end_timestamp = end_timestamp
                end
            end

            class ConfigSetsResult < Collection ; end
            class ConfigResult < Collection ; end
            class ConfigKeyResult < Collection; end

            @@cfn_cmd_log_path = '/var/log/cfn-init-cmd.log'
            @@configset_start_signature = '*' * 60
            @@config_start_signature = '+' * 60
            @@key_start_signature = '=' * 60
            @@output_start_signature = '-----------------------Command Output-----------------------'
            @@output_end_signature = '-' * 60

            @@line_parse_regex = /(^[\d\-\s\:\,]{23}) P(\d)+ \[(INFO|ERROR)\] (.*)$/
            @@exit_code_regex = /Exited with error code (\d+)/
            @@configset_name_regex = /ConfigSet (.+)/
            @@config_name_regex = /Config (.+)/
            @@test_command_name_regex = /Test for (.+)/

            @@read_buffer_size = 262144


            def self.parse(start_timestamp)
                CfnCmdLogParser.new.collect_entries(start_timestamp)
            end

            # collect named config outputs
            def initialize
                @results = []
                @failed_key = nil
                @failed_config = nil
                @failed_configset = nil

                @entries = []
                @text = []
                @end_timestamp = nil
            end

            def collect_entries(start_timestamp)
                scan_log_lines do |timestamp_str, content|
                    timestamp = Time.parse(timestamp_str)
                    # return if entry is older than cut timestamp
                    return @results, @failed_key, @failed_config, @failed_configset if timestamp - start_timestamp < 0

                    @end_timestamp ||= timestamp # record the end time of current entry
                    case content
                        when @@configset_start_signature  # find start of configset
                            parse_configset_result(start_time:timestamp, end_time: @end_timestamp)

                        when @@config_start_signature  # find start of config
                            parse_config_result(start_time: timestamp, end_time: @end_timestamp)

                        when @@key_start_signature # find start of config key
                            parse_key_result(start_time: timestamp, end_time: @end_timestamp)
                        else
                            @text << content # collecting lines
                    end
                end

                # if log file was truncated during executing configset, just send what is left
                @results.concat(@entries) if ! @entries.empty?
                return @results, @failed_key, @failed_config, @failed_configset
            end


            # scan log files lines by lines, and yield to proc for processing
            private
            def scan_log_lines
                File.open(@@cfn_cmd_log_path, 'r') do |f|
                    offset = f.size
                    buffer = ''
                    while offset > 0
                        if offset < @@read_buffer_size
                            read_size = offset
                            offset =  0
                        else
                            read_size = @@read_buffer_size
                            offset = offset - @@read_buffer_size
                        end

                        f.seek(offset)
                        buffer = f.read(read_size) + buffer
                        lines = buffer.split($/)
                        (lines.length - 1).downto(0) do |line_index|
                            # parse line
                            components = Utils.extract_strings(string: lines[line_index], regex: @@line_parse_regex, indices: [1,4])
                            if components.empty?
                                buffer = lines[0] if 0 == line_index  # adding back the first incomplete line
                                next # continue for non-parsable, empty or incomplete line
                            else
                                timestamp = components[0]
                                content = components[1]
                            end

                            yield timestamp, content
                        end
                    end
                end
            end


            # search for all tail top-level config results and wrap them to a new configset
            private
            def parse_configset_result(start_time:, end_time:)
                parse_aggregated_result(@@configset_name_regex) do |name|
                    index = @results.length
                    index = index - 1 while index > 0 && @results[index - 1].is_a?(ConfigResult)
                    configs = @results.slice!(index..-1)   # remove Config Results for wrapping
                    item = ConfigSetsResult.new(name: name, collections: configs,
                                                start_timestamp: start_time,
                                                end_timestamp: configs[0].nil? ? end_time : configs[0].end_timestamp)
                    @failed_configset ||= item if @failed_key
                    item
                end
            end


            # wrap all entries to a new config
            private
            def parse_config_result(start_time:, end_time:)
                parse_aggregated_result(@@config_name_regex) do |name|
                    item = ConfigResult.new(name: name, collections: @entries,
                                start_timestamp: start_time,
                                end_timestamp: @entries[0].nil? ? end_time : @entries[0].end_timestamp)
                    @failed_config ||= item if @failed_key
                    item
                end
            end


            private
            def parse_key_result(start_time:, end_time:)
                output = ''
                (@text.length - 3).downto(2) do |i|
                    output << @text[i] << $/
                end
                exit_code = Utils.extract_string(string: @text[0], regex: @@exit_code_regex)
                if Utils.extract_string(string: @text[-1], regex: @@test_command_name_regex)
                    # treat test failure as normal, though append exit code to log
                    exit_code = nil
                    output << $/ << @text[0]
                end
                item = ConfigKeyResult.new(name: @text[-1],
                                      exit_code: exit_code.nil? ? nil : exit_code.to_i,
                                      output: output,
                                      start_timestamp: start_time,
                                      end_timestamp: end_time)
                @entries << item

                # clear cache
                @text.clear
                @failed_key ||= item if item.exit_code   # only catch the last failure (and should be only one)
                @end_timestamp = nil
            end


            private
            def parse_aggregated_result(name_regex)
                name = Utils.extract_string(string: @text[-1], regex: name_regex)
                @results << yield(name)
                # clear cache
                @text.clear
                @entries = []
                @end_timestamp = nil
            end
        end
    end
end
