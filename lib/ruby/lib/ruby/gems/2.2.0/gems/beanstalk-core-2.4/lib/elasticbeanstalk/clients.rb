
require 'aws-sdk'
require 'elasticbeanstalk/environment'
 
module ElasticBeanstalk
    module Clients
        def self.s3_resource
            Aws::S3::Resource.new(client: self.s3_client)
        end

        def self.s3_client
            @@s3_client ||= Aws::S3::Client.new(region: Environment.region)
        end
    end
end
