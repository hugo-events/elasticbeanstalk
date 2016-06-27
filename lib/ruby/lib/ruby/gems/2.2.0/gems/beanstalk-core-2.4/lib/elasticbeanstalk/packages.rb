
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

require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/platform/packages-backend'

module ElasticBeanstalk
    class Packages
        # Install a package using the native package manager. Returns Array of installed packages
        #
        # === Examples
        # 
        #   ElasticBeanstalk::Packages.install %w[nginx tomcat7]   #=> ["nginx", "tomcat7"]
        #
        # === Attributes
        #
        # * +packages+ Package name as a String or Array of package names
        #
        def self.install(packages)
            packages = [packages].flatten

            Platform::PackagesBackend.install packages

            failed_packages = packages.collect do |package|
                package unless installed? package
            end
            if failed_packages.any?
                raise BeanstalkRuntimeError, %[Following packages failed to install: #{failed_packages.compact.join ', '}]
            end
            packages
        end

        # Returns true if the package is installed, otherwise returns false
        #
        # === Examples
        # 
        #   ElasticBeanstalk::Packages.installed? 'nginx'   #=> true
        #
        # === Attributes
        #
        # * +package+ Package name as a String
        def self.installed?(package)
            o = Platform::PackagesBackend.installed? package
            o.exitstatus == 0
        end
    end
end
