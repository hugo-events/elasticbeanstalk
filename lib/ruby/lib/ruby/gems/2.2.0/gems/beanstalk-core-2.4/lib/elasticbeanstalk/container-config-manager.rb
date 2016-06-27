
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

require 'json'

require 'elasticbeanstalk/command'
require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/environment-metadata'

module ElasticBeanstalk
    class ContainerConfigManager
        DEFAULT_CONFIG_FILE = Command.containerconfig_file

        def initialize(config_file = DEFAULT_CONFIG_FILE)
            @config_file = config_file
            configuration
        end

        def optionsetting(namespace, option_name = nil)
            if namespace.nil? && !option_name.nil?
                raise BeanstalkRuntimeError, %[Missing namespace!]
            end

            all_optionsettings = @container_configs["optionsettings"]

            all_optionsettings.each do |n, v|
                if v.is_a?(Array)
                    new_v = v.inject({}) do |hash, element|
                        key, value = element.split("=", 2)
                        hash[key] = value
                        hash
                    end
                    all_optionsettings[n] = new_v
                end
            end

            if namespace.nil?
                return all_optionsettings
            end

            namespace_configs = all_optionsettings[namespace]
            if namespace_configs.nil?
                raise BeanstalkRuntimeError, %[Namespace #{namespace} does not exist]
            end

            if option_name.nil?
                namespace_configs
            else
                namespace_configs[option_name]
            end
        end

        def addon_config(addon_name, key = nil)
            if addon_name.nil? && !key.nil?
                raise BeanstalkRuntimeError, %[Missing addon name!]
            end

            all_addons = @container_configs["plugins"]

            if addon_name.nil?
                return all_addons
            end

            addon_configs = all_addons[addon_name]
            if addon_configs.nil?
                raise BeanstalkRuntimeError, %[Addon does not exist]
            end

            if key.nil?
                addon_configs
            else
                addon_configs[key]
            end

        end

        def container_config(key)
            container_configs = @container_configs['container']

            if key.nil?
                return container_configs
            end

            container_configs[key]
        end

        def environment_variables(key = nil)
            env_optionsettings = optionsetting("aws:elasticbeanstalk:application:environment")
            add_ons = addon_config(nil)

            environment = {}
            env_optionsettings.each do |key, value|
                environment[key] = value unless value.nil?
            end

            if add_ons
                add_ons.each do |addon_name, addon_value|
                    if addon_value['env']
                        environment.merge!(addon_value['env'])
                    end
                end
            end

            key && environment ? environment[key] : environment
        end

        private
        def configuration
            @container_configs ||= begin
                JSON.parse(File.read(@config_file))
            end
        end
    end
end
