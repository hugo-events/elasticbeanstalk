
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

require 'open-uri'
require 'json'
require 'tempfile'
require 'logger'
require 'yaml'
require 'thread'

require 'elasticbeanstalk/activity'
require 'elasticbeanstalk/command'
require 'elasticbeanstalk/constants'
require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/command-heart-beat'
require 'elasticbeanstalk/utils'
require 'elasticbeanstalk/serialization/command_request'
require 'elasticbeanstalk/serialization/command_response'
require 'elasticbeanstalk/command_label'
require 'elasticbeanstalk/healthd_reporter'

module ElasticBeanstalk
    class CommandProcessor
        @@logfile_path = '/var/log/eb-commandprocessor.log'
        @@cache_dir='/var/lib/eb-tools/data/stages/'
        @@logger = nil

        def self.logger(logger:nil)
            if logger
                @@logger = logger
            else
                logger_file = File.open(@@logfile_path, 'a')
                logger_file.sync = true
                @@logger = Logger.new(logger_file,
                                        shift_age: Constants::LOG_SHIFT_AGE,
                                        shift_size: Constants::LOG_SHIFT_SIZE)
                @@logger.formatter = Utils.logger_formatter
            end
            @@logger
        end
        
        # Constructor to help in unit-testing
        def initialize(cache_dir: @@cache_dir, env_metadata: nil, logger: nil)
            @@logger = self.class.logger(logger: logger)
            @cache_dir = cache_dir.end_with?('/') ? cache_dir : "#{cache_dir}/"
            @env_metadata = env_metadata || EnvironmentMetadata.new(logger: @@logger)
        end
        
        def execute!(cmd_req)
            cmd_result = nil
            if execute_command?(cmd_req)
                command = load_command(cmd_req)
                manifest = Manifest.load_cache(logger: @@logger)

                HealthdReporter.log(cmd_req, manifest) do
                    execute_command(cmd_req) do
                        command_label = CommandLabel.for_name(cmd_req.command_name, stage: cmd_req.stage_num)

                        Activity.create(name: activity_name(command_label, cmd_req, manifest)) do
                            @@logger.info("Executing command: #{cmd_canonical_name(cmd_req)}...")
                            cmd_result = command.execute!

                            if cmd_result.status == CommandResult::SUCCESS
                                @@logger.info("Command #{cmd_canonical_name(cmd_req)} succeeded!")
                                "#{command_label} - Command #{cmd_canonical_name(cmd_req)} succeeded"
                            else
                                @@logger.error("Command #{cmd_canonical_name(cmd_req)} failed!")
                                "#{command_label} - Command #{cmd_canonical_name(cmd_req)} failed"
                            end
                        end
                        cmd_result
                    end
                end
            else
                @@logger.warn("Command processor shouldn't execute command.")
                cmd_result = CommandResult.new(status: CommandResult::FAILURE,
                                               return_code: 0,
                                               msg: 'Ignoring not applicable command.',
                                               ignored: true)
            end
        end

        private
        def activity_name(command_label, command_request, manifest)
            deployment_tag = CommandLabel.deployment_tag(name: command_request.command_name,
                                                         version_label: manifest ? manifest.version_label : nil,
                                                         deployment_id: manifest ? manifest.deployment_id : nil)

            if deployment_tag
                "#{command_label} #{deployment_tag}"
            else
                command_label
            end
        end

        private
        def execute_command?(cmd_req)
            @@logger.debug("Checking if the command processor should execute...")
            check_instance_command(cmd_req.instance_ids) && valid_stage?(cmd_req.stage_num, cmd_req.request_id)
        end

        private
        def load_command(cmd_req)
            @@logger.info("Received command #{cmd_canonical_name(cmd_req)}: #{cmd_req}")

            @@logger.info('Command processor should execute command.')
            store_stage_executed(cmd_req.request_id, cmd_req.stage_num, cmd_req.last_stage?)

            command = Command.load(cmd_req, logger: @@logger)
            command
        end

        private
        def execute_command(cmd_req)
            @@logger.info("Executing #{CommandLabel.for_name(cmd_req.command_name, stage: cmd_req.stage_num )}")
            tmp_events_file = events_file

            #ENACT
            cmd_result = yield

            cmd_result.process_events(tmp_events_file.path)
            @@logger.info("Command processor returning results: \n#{
                CommandResponse.generate(cmd_result: cmd_result, api_version: cmd_req.api_version)}")

            cmd_result
        end


        private
        def check_instance_command(cmd_instance_ids)
            instance_id = @env_metadata.instance_id
            @@logger.debug("Checking whether the command is applicable to instance (#{instance_id})..")
            if cmd_instance_ids && cmd_instance_ids.length > 0 && !cmd_instance_ids.include?(instance_id)
                @@logger.info("Command should not be executed on this instance (#{instance_id}).")
                return false
            end
            @@logger.info("Command is applicable to this instance (#{instance_id})..")
            return true
        end

        private
        def valid_stage?(current_stage, request_id)
            @@logger.debug("Checking if the received command stage is valid..")

            case current_stage
            when nil
                @@logger. info("No stage_num in command. Valid stage..")
                return true
            when 0
                @@logger.info("Stage_num=#{current_stage.to_s}. Valid stage..")
                return true
            else
                @@logger.debug("Stage_num=#{current_stage.to_s}. Checking previous stage..")
                prev_stage = read_previous_stage(request_id)

                if !prev_stage
                    @@logger.warn("Could not find a previous stage for request id: #{request_id}. Invalid stage..")
                    return false
                end
            
                if prev_stage == current_stage - 1
                    @@logger.info("Previous stage (#{prev_stage}) is one less that current stage (#{current_stage}). Valid stage..")
                    return true
                end
            
                @@logger.warn("Previous stage (#{prev_stage}) is not one less that current stage (#{current_stage}). Invalid stage..")
                return false
            end
        end

        private
        def read_previous_stage(request_id)
            stage_file = "#{@cache_dir}#{request_id}"
            @@logger.debug("Opening previous stage file #{stage_file}..")

            if !File.exists?(stage_file)
                @@logger.debug("Previous stage file does not exist. Returning nil.")
                return nil
            end
            
            contents = File.read(stage_file)
            @@logger.debug("Previous stage file contains: #{contents}.")
            if /\A\d+\Z/ =~ contents
                @@logger.debug("Returning #{contents}..")
                return contents.to_i
            else
                @@logger.debug("Previous stage file does not contain a valid integer. Returning nil.")
                return nil
            end
        end


        private
        def store_stage_executed(request_id, stage_num, is_last_stage)
            @@logger.debug("Storing current stage..")
            if stage_num == nil
                @@logger.debug("Stage_num does not exist. Not saving null stage. Returning..")
                return 
            end
            
            if is_last_stage
                @@logger.info("This was last stage for the command. Removing saved stage info for request..")
                FileUtils.rm("#{@cache_dir}#{request_id}", :force => true)
                return
            end

            @@logger.info("Saving stage #{stage_num}..")
            FileUtils.mkdir_p(@cache_dir)
            File.open("#{@cache_dir}#{request_id}", 'w') do |f|
                f.write(stage_num.to_s)
            end
        end


        private
        def events_file
            tempfile = Tempfile.new('eventsfile')
            ENV['EB_EVENT_FILE'] = tempfile.path
            Utils.set_eb_datafile_permission(tempfile.path)
            tempfile
        end

        private
        def cmd_canonical_name(cmd_data)
            name = cmd_data.command_name
            if cmd_data.stage_num
                name = name + %[(stage #{cmd_data.stage_num})]
            end
            name
        end
    end
    
end
