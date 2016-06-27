
require 'aws-sdk'

require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/http_utils'

module ElasticBeanstalk
    module Environment

        def self.environment_id
            @@environment_id ||= metadata.environment_id
        end

        def self.region
            @@region ||= metadata.region
        end

        def self.environment_s3_bucket
            @@environment_bucket ||= metadata.environment_bucket
        end

        private
        def self.metadata
            # where is logger?
            @@environment_metadata ||= EnvironmentMetadata.new
        end
    end
end
