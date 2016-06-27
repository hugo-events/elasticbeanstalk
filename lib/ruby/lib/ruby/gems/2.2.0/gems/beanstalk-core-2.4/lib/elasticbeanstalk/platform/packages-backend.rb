
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

require 'executor'
require 'elasticbeanstalk/platform'

module ElasticBeanstalk
    module Platform
        class PackagesBackend
            extend Executor

            def self.install(packages)
                case
                when ElasticBeanstalk::Platform.amazon_linux?
                    sh %[yum install -y #{packages.join ' '}]
                else
                    ElasticBeanstalk::Platform.unsupported_operating_system!
                end
            end

            def self.installed?(package)
                case
                when ElasticBeanstalk::Platform.amazon_linux?
                    sh %[rpm -qi #{package}], :raise_on_error => false
                else
                    ElasticBeanstalk::Platform.unsupported_operating_system!
                end
            end
        end
    end
end
