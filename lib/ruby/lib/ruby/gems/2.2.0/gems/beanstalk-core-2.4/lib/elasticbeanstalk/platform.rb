
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

module ElasticBeanstalk
    module Platform
        @@amazon_linux = 'amazon-linux'
        @@red_hat = 'red_hat'
        @@ubuntu = 'ubuntu'

        @@proc_version_path = '/proc/version'
        @@system_release_path = '/etc/system-release'
        @@proc_cpuinfo_path = '/proc/cpuinfo'

        def self.operating_system
            os = case Gem::Platform.local.os
            when 'linux'
                if system_release[/\bAmazon Linux\b/]
                    @@amazon_linux
                else
                    case proc_version
                    when /\bRed Hat\b/
                        @@red_hat
                    when /\bUbuntu\b/
                        @@ubuntu
                    end
                end
            end

            unsupported_operating_system! unless os
            os
        end

        def self.amazon_linux?
            operating_system == @@amazon_linux rescue false
        end

        def self.red_hat?
            operating_system == @@red_hat rescue false
        end

        def self.ubuntu?
            operating_system == @@ubuntu rescue false
        end

        def self.architecture
            Gem::Platform.local.cpu
        end

        def self.processor_count
            proc_cpuinfo.scan(/^processor\b/).count if proc_cpuinfo
        end

        def self.unsupported_operating_system!
            raise BeanstalkRuntimeError, %[Unsupported operating system: "#{Gem::Platform.local.os}"]
        end

        private
        def self.system_release
            @@system_release ||= File.read @@system_release_path if File.exists? @@system_release_path
        end

        private
        def self.proc_version
            @@proc_version ||= File.read @@proc_version_path if File.exists? @@proc_version_path
        end

        private
        def self.proc_cpuinfo
            @@proc_cpuinfo ||= File.read @@proc_cpuinfo_path if File.exists? @@proc_cpuinfo_path
        end
    end    
end
