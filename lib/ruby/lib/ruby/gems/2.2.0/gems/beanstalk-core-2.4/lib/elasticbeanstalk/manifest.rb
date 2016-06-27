
require 'aws-sdk'
require 'fileutils'
require 'json'

require 'elasticbeanstalk/environment'
require 'elasticbeanstalk/clients'

module ElasticBeanstalk
    class ManifestDownloadError < RuntimeError; end

    class Manifest
        MANIFEST_KEY_TEMPLATE = "resources/environments/%{env_id}/_runtime/versions/%{filename}".freeze
        DEFAULT_MAX_RETRY = 5

        MANIFEST_CACHE_PATH = '/opt/elasticbeanstalk/deploy/manifest'

        attr_reader :manifest_hash

        def self.load_cache(logger:, cache_path: MANIFEST_CACHE_PATH)
            content = File.read(cache_path)
            manifest_hash = JSON.parse(content)
            Manifest.new(manifest_hash: manifest_hash)
        rescue => ex
            logger.info("Cannot load manifest cache because: #{ex.message}")
            nil
        end

        def self.update_cache(logger:, cmd_req: nil, metadata: nil, cache_path: MANIFEST_CACHE_PATH)
            metadata ||= EnvironmentMetadata.new(logger: logger)

            if ! metadata.instance_profile_specified?
                logger.info("Instance doesn't have IAM instance profile attached. Skipped fetching manifest.")
                return nil
            end

            manifest_s3_key = metadata.manifest_s3_key
            if cmd_req
                manifest_filename = cmd_req.data
            else
                manifest_filename = ENV['EB_COMMAND_DATA']
            end
            manifest = Manifest.fetch(logger:logger,
                                      manifest_s3key: manifest_s3_key,
                                      manifest_filename: manifest_filename)

            manifest.save(cache_path: cache_path)
            logger.info("Updated manifest cache: deployment ID #{manifest.deployment_id} and serial #{manifest.serial}.")
            manifest
        end

        def initialize(manifest_hash:)
            @manifest_hash = manifest_hash
        end

        def application_name
            runtime_sources.keys.first if runtime_sources
        end

        def version_label
            return nil unless @manifest_hash

            if @manifest_hash['VersionLabel']
                @manifest_hash['VersionLabel']
            else
                application_node = runtime_sources.values.first if runtime_sources
                application_node.keys.first if application_node
            end
        end

        def deployment_id
            @manifest_hash ? @manifest_hash['DeploymentId'] : nil
        end

        def serial
            @manifest_hash ? @manifest_hash['Serial'] : nil
        end

        def save(cache_path: MANIFEST_CACHE_PATH)
            FileUtils.mkdir_p(File.dirname(cache_path))
            File.write(cache_path, JSON.dump(@manifest_hash))
            Utils.set_eb_datafile_permission(cache_path)
        end

        def self.fetch(logger:, manifest_s3key: nil, manifest_filename: nil, max_retry_count: DEFAULT_MAX_RETRY)
            attempt ||= 0
            attempt = attempt + 1

            bucket_name = Environment.environment_s3_bucket
            s3 = Clients.s3_resource
            if manifest_s3key
                # manifest_s3key takes highest priority if specified
                manifest_s3key = manifest_s3key.strip
                logger.info "Loading manifest from bucket '#{bucket_name}' using specified S3 key '#{manifest_s3key}'."
                manifest = s3.bucket(bucket_name)
                               .object(manifest_s3key)
            elsif manifest_filename
                # then uses computed key from manifest filename if specified
                s3key = manifest_key(manifest_filename.strip)
                logger.info "Loading manifest from bucket '#{bucket_name}' using computed S3 key '#{s3key}'."
                manifest = s3.bucket(bucket_name)
                               .object(s3key)
            else
                # otherwise search for latest manifest
                s3_prefix = manifest_key_prefix
                logger.info "Finding latest manifest from bucket '#{bucket_name}' with prefix '#{s3_prefix}'."
                manifest = latest_key(s3: s3, bucket_name: bucket_name, s3_prefix: s3_prefix)
                logger.info "Found manifest with key '#{manifest.key}'." if manifest
            end
            raise ManifestDownloadError.new('No manifest found.') unless manifest

            manifest_contents = manifest.get.body.read
            manifest_hash = JSON.parse(manifest_contents)
            Manifest.new(manifest_hash: manifest_hash)
        rescue => e
            error_message = if manifest_s3key
                                "Failed to fetch manifest with key #{manifest_s3key} from #{bucket_name}, reason: #{e.message}"
                            elsif manifest
                                "Failed to fetch manifest with key #{manifest.key} from #{bucket_name}, reason: #{e.message}"
                            else
                                "Failed to fetch manifest from #{bucket_name}, reason: #{e.message}"
                            end
            error_message << '.' unless error_message.end_with?('.')

            if attempt < max_retry_count
                backoff = Utils.random_backoff(attempt)
                logger.warn "#{error_message} Retrying after #{backoff} seconds."
                sleep backoff

                retry
            else
                logger.warn error_message
                raise ManifestDownloadError.new(error_message)
            end
        end

        def runtime_sources
            @manifest_hash ? @manifest_hash['RuntimeSources'] : nil
        end

        private
        def self.latest_key(s3:, bucket_name:, s3_prefix:)
            manifest = s3.bucket(bucket_name)
                           .objects(prefix: s3_prefix)
                           .max_by { |o| o.last_modified }
            manifest
        end

        private
        def self.manifest_key_prefix
            MANIFEST_KEY_TEMPLATE % { :env_id => Environment.environment_id, :filename => 'manifest_' }
        end

        private
        def self.manifest_key(filename)
            MANIFEST_KEY_TEMPLATE % { :env_id => Environment.environment_id, :filename => filename}
        end
    end
end

