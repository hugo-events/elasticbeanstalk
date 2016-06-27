
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

require 'yaml'

require 'elasticbeanstalk/activity'
require 'elasticbeanstalk/hook-directory-executor'
require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/exceptions'

module ElasticBeanstalk

    class AddonManager

        CONFIG_ADDONS_KEY = 'addons'

        @@addon_path = '/opt/elasticbeanstalk/addons'
        ADDON_CONF_FILENAME = 'addon_def.yaml'
        HOOKS_SUBDIR_NAME = 'hooks'

        def initialize (env_metadata:, addon_path: @@addon_path, logger: Logger.new(File.open(File::NULL, "w")))
            @env_metadata = env_metadata
            @addon_path = addon_path
            @logger = logger

        end

        def enabled_addons
            if @addons.nil?
              @addons = search_enabled_addons.collect { |name| import_addon(name) }

              # To make simple assumption addons will run in random order, see TODO in class Addon
              # @addons.sort_by! {|addon| [addon.order, addon.name]}
            end
            @addons
        end


        def update_command_def (cmds_def)
            original_cmd_names = cmds_def.keys
            enabled_addons.each do |addon|
                @logger.info("Updating Command definition of addon #{addon.name}.")

                commands = addon.commands
                duplicate_commands = commands.keys & cmds_def.keys
                if ! duplicate_commands.empty?
                    raise BeanstalkRuntimeError, "Addon #{addon.name} conflicts with existing definition of commands: #{duplicate_commands}."
                end
                cmds_def.update(commands)
            end

            added_commands = cmds_def.keys - original_cmd_names
            @logger.info("Added Commands: #{added_commands}") if ! added_commands.empty?
            cmds_def
        end


        def run_addons_before (cmd_name:)
            enabled_addons.each do |addon|
                actions = addon.hooks_before(cmd_name: cmd_name)
                if ! actions.empty?
                    run_actions(addon_name: addon.name, actions: actions)
                end
            end
            nil # return nothing since all actions are wrapped in Activity
        end


        def run_addons_after (cmd_name:)
            enabled_addons.each do |addon|
                actions = addon.hooks_after(cmd_name: cmd_name)
                if ! actions.empty?
                    run_actions(addon_name: addon.name, actions: actions)
                end
            end
            nil # return nothing since all actions are wrapped in Activity
        end

        #
        #  private methods
        #
        private
        def search_enabled_addons
            addon_names = populate_hardcoded_addons
            @logger.info("Found enabled addons: #{addon_names}.")
            addon_names
        end


        private
        def populate_hardcoded_addons
            addon_names = []

            # log publication addon is always enabled
            addon_names << 'logpublish'

            # check worker tier, currently only the single bundled version is supported
            commands = @env_metadata.metadata(path: "AWS::ElasticBeanstalk::Ext||_API||_Commands")
            addon_names << 'sqsd' if commands.has_key?('CMD-SqsdDeploy')

            addon_names
        end


        private
        def populate_addons
            addons = @env_metadata.container_config.fetch(CONFIG_ADDONS_KEY, {})
            addons.keys
        end


        private
        def import_addon (addon_name)
            def_filepath = File.join(@addon_path, addon_name, ADDON_CONF_FILENAME)
            Addon.new(addon_def: YAML.load_file(def_filepath))
        end


        private
        def run_actions (addon_name:, actions:)
            hooks_root = File.join(@addon_path, addon_name, HOOKS_SUBDIR_NAME)
            actions.each do |action|
                Activity.create(name: action.name) do
                    case action.type
                        when 'addon-hook'
                            HookDirectoryExecutor.new.run!(File.join(hooks_root, action.value))
                        when 'sh'
                            Executor::Exec.sh(action.value)
                        else
                            raise BeanstalkRuntimeError, "Not recognized hook action type: #{action.type}."
                    end
                end
            end
        end


        class Addon
            NAME_KEY        = 'name'
            VERSION_KEY     = 'version'
            DESCRIPTION_KEY = 'description'
            COMMANDS_KEY    = 'commands'
            HOOKS_KEY       = 'hooks'

            HOOKS_BEFORE_KEY = 'before'
            HOOKS_AFTER_KEY  = 'after'

            attr_reader :name, :version, :description, :commands

            # name and version are required
            def initialize (addon_def:)
                @name = addon_def.fetch(NAME_KEY) || "" #override nil generated by YAML parser
                @version = addon_def.fetch(VERSION_KEY) || 0    #override nil generated by YAML parser
                #@order = addon_def.fetch(ORDER_KEY)    # see above TODO
                @description = addon_def.fetch(DESCRIPTION_KEY, "") || "" #override nil generated by YAML parser
                @commands = addon_def.fetch(COMMANDS_KEY, {}) || {} #override nil generated by YAML parser
                hooks_def = addon_def.fetch(HOOKS_KEY, {}) || {} #override nil generated by YAML parser
                @hooks_before_hash = {}
                @hooks_after_hash = {}

                hooks_def.each do |cmd_name, hooks|
                    @hooks_before_hash[cmd_name] = []
                    hooks_before_def = hooks.fetch(HOOKS_BEFORE_KEY, [])
                    hooks_before_def.each do |item|
                        @hooks_before_hash[cmd_name] << Action.new(item)
                    end

                    @hooks_after_hash[cmd_name] = []
                    hooks_after_def = hooks.fetch(HOOKS_AFTER_KEY, [])
                    hooks_after_def.each do |item|
                        @hooks_after_hash[cmd_name] << Action.new(item)
                    end
                end
            end


            def hooks_before(cmd_name:)
                @hooks_before_hash.fetch(cmd_name, [])
            end


            def hooks_after(cmd_name:)
                @hooks_after_hash.fetch(cmd_name, [])
            end


            class Action
                attr_reader :name, :type, :value
                def initialize (args)
                    @name = args.fetch('name')
                    @type = args.fetch('type')
                    @value = args.fetch('value')
                end
            end
        end
    end
end
