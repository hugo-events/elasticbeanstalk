
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

require 'logger'
require 'open-uri'

require 'elasticbeanstalk/activity'
require 'elasticbeanstalk/addon'
require 'elasticbeanstalk/cfn-wrapper'
require 'elasticbeanstalk/command-result'
require 'elasticbeanstalk/command_label'
require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/executable'
require 'elasticbeanstalk/hook-directory-executor'
require 'elasticbeanstalk/manifest'

module ElasticBeanstalk

    class Command
        REFRESH_MANIFEST_KEY = 'refresh_manifest'
        PERSISTENT_CONFIGURATION_KEY = 'persistent_configuration'

        @@hooks_root = "/opt/elasticbeanstalk/hooks/"
        @@infra_root = "/opt/elasticbeanstalk/eb_infra/"

        @@deploy_config_dir = '/opt/elasticbeanstalk/deploy/configuration/'
        @@appsourceurl_file = File.join(@@deploy_config_dir, 'appsourceurl')
        @@containerconfig_file = File.join(@@deploy_config_dir, 'containerconfiguration')
        @@sourcebundle_file = '/opt/elasticbeanstalk/deploy/appsource/source_bundle'


        def self.load(cmd_data, logger: Logger.new(File.open(File::NULL, "w")))
            env_metadata = EnvironmentMetadata.new(logger: logger)
            addon_manager = ElasticBeanstalk::AddonManager.new(env_metadata: env_metadata, logger: logger)
            command_def = fetch_command_definition(cmd_data: cmd_data, env_metadata: env_metadata,
                                                   addon_manager: addon_manager)
            unless command_def && command_def[PERSISTENT_CONFIGURATION_KEY]
                # refresh metadata for each command we receive(because of addons), unless current definition says not to
                env_metadata.refresh(request_id: cmd_data.request_id, resource: cmd_data.resource_name)
                addon_manager = ElasticBeanstalk::AddonManager.new(env_metadata: env_metadata, logger: logger)
                command_def = fetch_command_definition(cmd_data: cmd_data, env_metadata: env_metadata,
                                                       addon_manager: addon_manager)
            end

            if command_def
                if command_def[REFRESH_MANIFEST_KEY]
                    Manifest.update_cache(logger: logger, cmd_req: cmd_data, metadata: env_metadata)
                end

                command = ContainerDefinitionCommand.new(cmd_data: cmd_data,
                                                         name: cmd_data.command_name,
                                                         definition: command_def,
                                                         addon_manager: addon_manager,
                                                         env_metadata: env_metadata,
                                                         logger: logger)
            else
                command = TemplateCommand.new(cmd_data: cmd_data, env_metadata: env_metadata, logger: logger)
            end
            command
        end

        def self.deploy_config_dir
            @@deploy_config_dir
        end
        
        def self.appsourceurl_file
            @@appsourceurl_file
        end
        
        def self.containerconfig_file
            @@containerconfig_file
        end
        
        def self.sourcebundle_file
            @@sourcebundle_file
        end

        private
        def self.fetch_command_definition(cmd_data:, env_metadata:, addon_manager:)
            command_defs = env_metadata.command_definitions
            command_defs = addon_manager.update_command_def(command_defs)
            command_def = command_defs.fetch(cmd_data.command_name, nil)
            command_def
        end

        private
        def initialize(cmd_data:, env_metadata:, logger:)
            @cmd_data = cmd_data
            @logger = logger
            @env_metadata = env_metadata
        end

        private
        def set_environment_variables(cmd_data)
            @logger.debug("Setting environment variables..")
            ENV['EB_RESOURCE_NAME'] = cmd_data.resource_name if cmd_data.resource_name
            ENV['EB_COMMAND_DATA'] = cmd_data.data if cmd_data.data
            ENV['EB_EXECUTION_DATA'] = cmd_data.execution_data if cmd_data.execution_data
            ENV['EB_REQUEST_ID'] = cmd_data.request_id if cmd_data.request_id
        end

        private
        def elect_leader (cmd_data)
            if @env_metadata.leader?(cmd_data)
                ENV['EB_IS_COMMAND_LEADER'] = 'true'
            else
                ENV['EB_IS_COMMAND_LEADER'] = 'false'
            end
        end
    end


    class ContainerDefinitionCommand < Command

        STAGES_KEY = 'stages'

        ACTION_INFRA = 'infra'
        ACTION_HOOK = 'hook'
        ACTION_SH = 'sh'

        def initialize(cmd_data:, name:, definition:, addon_manager:, env_metadata:,
                       hooks_root: @@hooks_root, infra_root: @@infra_root,
                       logger: Logger.new(File.open(File::NULL, "w")))
            super(cmd_data: cmd_data, env_metadata: env_metadata, logger: logger)
            @name = name
            @addon_manager = addon_manager

            @stages = definition.fetch(STAGES_KEY).collect do |stage_hash|
                Stage.new(stage_hash)
            end
            @logger.debug("Loaded definition of Command #{@name}.")

            @hooks_root = hooks_root
            @infra_root = infra_root
        end

        def execute!
            cmd_result = CommandResult.new
            @logger.info("Executing command #{@name} activities...")
            begin
                set_environment_variables(@cmd_data)

                cur_stage_index = @cmd_data.stage_num ? @cmd_data.stage_num : 0
                end_stage_index = @cmd_data.stage_num ? @cmd_data.stage_num : stage_count - 1

                if cur_stage_index == 0 # if this the first stage
                    @logger.info("Running AddonsBefore for command #{@name}...")
                    Activity.create(name: "AddonsBefore") do
                        @addon_manager.run_addons_before(cmd_name: @name)
                    end
                end

                @logger.debug("Running stages of Command #{@name} from stage #{cur_stage_index} to stage #{end_stage_index}...")
                while cur_stage_index <= end_stage_index
                    exec_stage(cur_stage_index: cur_stage_index)
                    cur_stage_index += 1
                end

                if cur_stage_index == stage_count   # if this the last stage
                    @logger.info("Running AddonsAfter for command #{@name}...")
                    Activity.create(name: "AddonsAfter") do
                        @addon_manager.run_addons_after(cmd_name: @name)
                    end
                end

                cmd_result.status = CommandResult::SUCCESS
                cmd_result.return_code = 0
            rescue Exception => e
                @logger.error("Command execution failed: #{ElasticBeanstalk.format_exception(e)}")
                cmd_result.status = CommandResult::FAILURE
                cmd_result.exception = e
            end
            cmd_result
        end

        private
        def infrahook_dir
            File.join(File.dirname(File.expand_path(__FILE__)), "infrahooks")
        end

        private
        def stage_count
            @stages.length
        end

        private
        def stage (index:)
            @stages.fetch(index)
        end

        private
        def exec_stage(cur_stage_index:)
            @logger.info("Running stage #{cur_stage_index} of command #{@name}...")
            cur_stage = stage(index: cur_stage_index)

            execution_data_json = begin
                JSON.parse(@cmd_data.execution_data)
            rescue JSON::ParserError
                @logger.info("execution_data not in JSON format #{@cmd_data.execution_data}")
            end if @cmd_data.execution_data

            if cur_stage_index == 0 && execution_data_json && execution_data_json["leader_election"] == "true"
                elect_leader(@cmd_data)
            else
                ENV['EB_IS_COMMAND_LEADER'] = 'false'
            end

            Activity.create(name: cur_stage.name) do
                @logger.debug("Loaded #{cur_stage.actions.length} actions for stage #{cur_stage_index}.")

                cur_stage.actions.each_with_index do |action, index|
                    @logger.info("Running #{index + 1} of #{cur_stage.actions.length} actions: #{action.name}...")
                    Activity.create(name: action.name) do
                        case action.type
                            when ACTION_INFRA
                                Dir.chdir(@infra_root) { Executable.create(action.value, eb_executable: true).execute! }
                            when ACTION_HOOK
                                HookDirectoryExecutor.new.run!(File.join(@hooks_root, action.value))
                            when ACTION_SH
                                Executor::Exec.sh(action.value)
                            else
                                raise BeanstalkRuntimeError, "Not recognized action type: #{action.type}."
                        end
                    end
                end

                command_label = CommandLabel.for_name(@name, stage: cur_stage_index)
                "#{command_label} - Command #{@name} stage #{cur_stage_index} completed"
            end
        end

        class Stage
            NAME_KEY = 'name'
            ACTIONS_KEY = 'actions'

            attr_reader :name, :actions

            def initialize (args)
                @name = args.fetch(NAME_KEY)

                @actions = args.fetch(ACTIONS_KEY).collect do |x|
                    Action.new(x)
                end
            end
        end

        class Action
            NAME_KEY = 'name'
            TYPE_KEY = 'type'
            VALUE_KEY = 'value'

            attr_reader :name, :type, :value

            def initialize (args)
                @name = args.fetch(NAME_KEY)
                @type = args.fetch(TYPE_KEY)
                @value = args.fetch(VALUE_KEY)
            end
        end
    end


    class TemplateCommand < Command
        def initialize(cmd_data:, env_metadata:, logger: Logger.new(File.open(File::NULL, "w")))
            super(cmd_data: cmd_data, env_metadata: env_metadata, logger: logger)
        end

        def execute!
            cmd_result = CommandResult.new
            config_sets = []
            begin
                set_environment_variables(@cmd_data)
                config_sets = @env_metadata.command_config_sets(@cmd_data)

                Activity.create(name: 'cfn-init-call') do
                    CfnWrapper.run_config_sets(env_metadata: @env_metadata, config_sets: config_sets.join(","))
                end
                cmd_result.status = CommandResult::SUCCESS
                cmd_result.return_code = 0
            rescue Exception => e
                @logger.error("Command execution failed: #{e.message}")
                cmd_result.status = CommandResult::FAILURE
                cmd_result.exception = e
                cmd_result.config_sets = config_sets.join(",")
            end
            cmd_result
        end
    end
end
