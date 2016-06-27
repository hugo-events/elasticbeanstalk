
require 'aws-sdk'
require 'elasticbeanstalk/clients'
require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/http_utils'
require 'elasticbeanstalk/utils'


####
## This script downloads the application version according to the dictates of
##    1) data in the manifest file
##    2) the default value of the app source environment parameter
##
##  If the manifest file exists:
##     - If runtime sources are not specified at all - then NO application version code will be downloaded at all
##           This allows supporting containers that have a sample app defined, but the customer/service wants no
##           code deployed
##     - If runtime sources are specified - but is empty - then the default app source environment parameter is 
##           used
##           If the default app source environment parameter is empty, then no code is downloaded
##     - Pull out the application version object from runtime sources
##        - If s3url field is populated (i.e. non-blank) - download using s3 url  (assumes a public or presigned
##                url)
##        - If s3_bucket, s3_key, s3_version_id fields are populated (i.e. non-blank)  - download using sdk 
##               from that location
##               if s3_key is specified, but s3_bucket is not, the environment bucket will be used
##        - If no fields are populated - download using sdk using fall back hard-coded "computed" s3 location
##               (parameterized by env id, app name and version label)
##  If the manifest file does not exist:
##     - download using default app source environment parameter (assumes public or presigned url)
##           If the default app source environment parameter is empty, then no code is downloaded
##
####
module ElasticBeanstalk
    class ApplicationVersionDownloader
        SOURCE_BUNDLE_S3_KEY_TEMPLATE = "resources/environments/%{env_id}/_runtime/_versions/%{app_name}/%{version_label}".freeze
        S3_URL_MANIFEST_KEY = 's3url'.freeze   ## this is preexisting spelling
        S3_BUCKET_MANIFEST_KEY = 's3_bucket'.freeze
        S3_KEY_MANIFEST_KEY = 's3_key'.freeze
        S3_VERSION_MANIFEST_KEY = 's3_version'.freeze

        @@max_retry_count = 5

        class RetriableDownloadError < RuntimeError;
        end

        class FatalDownloadError < RuntimeError;
        end

        def initialize(logger:, manifest: nil, max_retry_count: @@max_retry_count)
            @logger = logger
            @manifest = manifest
            @max_retry_count = max_retry_count
        end

        def download_to(destination:)
            @logger.info("Attempting to download application source bundle to: '#{destination}'.")
            begin
                attempt ||= 0
                attempt += 1

                ## If there is no manifest, or if the manifest runtime_sources is specified & empty,
                ##   then download from the default app source url
                if !@manifest || (@manifest.runtime_sources && @manifest.runtime_sources.empty?)
                    @logger.info('Downloading default application source bundle.')
                    download_default_app_source(destination: destination)
                    return
                end
                ## After this check, we know the manifest must exist (otherwise it would have
                ##   exited in the above check)

                ## If runtime sources not present in manifest file at all - then nothing to download
                ##   (not even sample).  This is the mechanism by which we can deliberately bypass 
                ##   the sample for containers that define one
                if !@manifest.runtime_sources
                    @logger.info('No application version requested for download.')
                    return
                end

                application_name = @manifest.application_name
                version_label = @manifest.version_label
                if blank?(version_label)
                    raise FatalDownloadError.new('Cannot download source bundle. Application name is specified with no version label.')
                end
                version_info = @manifest.runtime_sources[application_name][version_label] || {}

                ## Download from fully specified s3_url if specified (assumes public or presigned url)
                s3_url = version_info['s3url']
                if !blank?(s3_url)
                    download_from_url(destination: destination, url: s3_url)
                    return
                end

                ## Note: If we add other indicators to download the source from some other 
                ##  location/protocol (e.g. git) those mechanisms should be added before this point.

                ## Download using sdk
                download_using_s3_specification(destination: destination, 
                                                application_name: application_name, 
                                                version_label: version_label, 
                                                version_info: version_info)
            rescue FatalDownloadError => e # fatal no retry
                @logger.error(e.message)
                raise e
            rescue => e
                error_message = "Error downloading application version. #{e.message}"
                error_message << '.' unless error_message.end_with?('.')

                if attempt < @max_retry_count
                    backoff = Utils.random_backoff(attempt)
                    @logger.warn "#{error_message} Retrying after #{backoff} seconds."
                    sleep backoff

                    retry
                else
                    @logger.error error_message
                    raise FatalDownloadError.new(error_message)
                end
            end
        end


        private
        def blank? (str)
            str.nil? || str.strip.empty?
        end

        # Downloads the default version source bundle as defined by the container app source parameter
        private
        def download_default_app_source (destination:)
            url = EnvironmentMetadata.new(logger:@logger).app_source_url
            if !blank?(url)
                download_from_url(destination: destination, url: url)
            else 
                @logger.info('No default application defined to download.')
            end
        end

        # Downloads using s3 specification: bucket/key/version
        # The s3 key used will be either the s3_key field in the manifest, or computed
        # The s3 bucket will be either the s3_bucket field in the manifest, or the environment s3 bucket
        # The version will be either be the s3_version field in the manifest, or nil
        private
        def download_using_s3_specification (destination:, application_name:, version_label:, version_info:)
            s3_key = version_info[S3_KEY_MANIFEST_KEY]
            if blank?(s3_key)
                @logger.info('Using computed s3 key.')
                s3_key = compute_bundle_s3_key(environment_id: Environment.environment_id,  
                                               application_name: application_name, version_label: version_label)
            end

            s3_bucket = version_info[S3_BUCKET_MANIFEST_KEY]
            if blank?(s3_bucket)
                s3_bucket = Environment.environment_s3_bucket
            end

            s3_version = nil
            if !blank?(version_info[S3_VERSION_MANIFEST_KEY])
                s3_version = version_info[S3_VERSION_MANIFEST_KEY]
            end
            
            download_from_s3_location(destination: destination, s3_bucket: s3_bucket, 
                                      s3_key: s3_key, s3_version: s3_version)
        end

        private
        def compute_bundle_s3_key (environment_id:, application_name:, version_label:)
            SOURCE_BUNDLE_S3_KEY_TEMPLATE % { :env_id => environment_id, 
                :app_name => application_name, 
                :version_label => version_label }
        end

        private
        def download_from_s3_location (destination:, s3_bucket:, s3_key:, s3_version: nil)
            s3 = Clients.s3_resource

            @logger.info("Downloading from bucket '#{s3_bucket}' with key '#{s3_key}' and version '#{s3_version}' to '#{destination}'.")
            begin
                if s3_version
                    s3.bucket(s3_bucket).object(s3_key).version(s3_version).get(response_target: destination)
                else
                    s3.bucket(s3_bucket).object(s3_key).get(response_target: destination)
                end
                @logger.info "Successfully downloaded to '#{destination}'."
            rescue Aws::Errors::ServiceError => e
                error_message = "Could not download from bucket '#{s3_bucket}' with key '#{s3_key}' and version '#{s3_version}', reason: (#{e.class}) #{e.message}"
                error_message << '.' unless error_message.end_with?('.')
                raise RetriableDownloadError.new(error_message)
            end
        end

        private
        def download_from_url(destination:, url:)
            @logger.info("Downloading from URL: '#{url}' to '#{destination}'.")
            HttpUtils.download_to(source_uri: url, destination: destination, max_retries: 1)
            @logger.info "Successfully downloaded to '#{destination}'."
        end

    end
end
