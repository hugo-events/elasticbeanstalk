require 'json'
require 'oj'
require 'tempfile'
require 'fileutils'

require 'elasticbeanstalk/command-processor'
require 'elasticbeanstalk/command_label'
require 'elasticbeanstalk/healthd'

module ElasticBeanstalk
    class HealthdReporter
        @@current_status_file = '/var/elasticbeanstalk/healthd/current.json'
        @@latest_status_file  = '/var/elasticbeanstalk/healthd/latest.json'

        @@supported_commands = ['CMD-PreInit', 'CMD-AppDeploy', 'CMD-ConfigDeploy',
                                'CMD-SqsdDeploy', 'CMD-Startup', 'CMD-SelfStartup'
                               ]

        @@truncation_message = "\n\nCommand output has been truncated. Please see logs for more details."

        @@max_message_length = 10_000

        def initialize(command_request, manifest)
            @command_request = command_request
            @command_label = CommandLabel.for_name(@command_request.command_name, stage: @command_request.stage_num)
            @start_time = Time.now.to_f
            @manifest = manifest
        end

        def self.log(command_request, manifest)
            raise "block expected" unless block_given?

            unless Healthd.enabled? && @@supported_commands.include?(command_request.command_name)
                result = yield self
                return result
            end

            reporter = self.new(command_request, manifest)
            reporter.start
            result = yield self
            if result.ignored
                reporter.clean_current_file
            else
                reporter.finish(result)
            end
            result
        rescue Exception => e
            reporter.finish_with_exception(e) if Healthd.enabled?
            raise e
        end

        def start
            existing_current = read_current
            @start_time = existing_current && existing_current['start_time'] || @start_time
            current_status = {
                'command'    => @command_label,
                'start_time' => @start_time
            }
            add_version_info!(current_status)
            write_through_tmp_file(@@current_status_file, Oj.dump(current_status))
        end

        def finish(cmd_result)
            message = extract_message(cmd_result)
            return_code = extract_return_code(cmd_result)

            if return_code != 0 || cmd_result.status == CommandResult::FAILURE ||
                !CommandLabel.wait_for_next_command?(@command_request.command_name, stage: @command_request.stage_num)

                latest_status = {
                    'command'     => @command_label,
                    'start_time'  => @start_time,
                    'end_time'    => Time.now.to_f,
                    'status'      => cmd_result.status,
                    'exit_status' => return_code,
                    'message'     => truncate(message)
                }
                add_version_info!(latest_status)
                current_to_latest(latest_status)
            end
        end

        def read_current
            if File.file?(@@current_status_file)
                current_contents = File.read(@@current_status_file)
                Oj.load(current_contents)
            end
        end

        def finish_with_exception(e)
            latest_status = {
                'command'     => @command_label,
                'start_time'  => @start_time,
                'end_time'    => Time.now.to_f,
                'status'      => 'error',
                'exit_status' => 255,
                'message'     => truncate(e.message)
            }
            add_version_info!(latest_status)

            current_to_latest(latest_status)
        end

        def clean_current_file
            FileUtils.rm_f @@current_status_file
        end

        private
        def current_to_latest(contents)
            latest_status_json = Oj.dump(contents)
            # write to current first so that we don't have the same command name in two files
            write_through_tmp_file(@@current_status_file, latest_status_json)

            # atomically make current the latest
            FileUtils.mv @@current_status_file, @@latest_status_file
        end

        private
        def add_version_info!(command_status)
            if @manifest
                command_status['version_label'] = @manifest.version_label if @manifest.version_label # may be absent
                command_status['deployment_id'] = @manifest.deployment_id.to_i if @manifest.deployment_id
                command_status['serial']        = @manifest.serial.to_i if @manifest.serial
            end
            nil
        end

        private
        def extract_message(cmd_result)
            return cmd_result.msg unless cmd_result.exception && cmd_result.status == CommandResult::FAILURE

            ex = cmd_result.exception
            if ex.is_a?(ActivityFatalError) && ex.root_exception
                root = ex.root_exception
                if root.is_a?(ExternalInvocationError)
                    return "#{root.reason.strip}\n\n#{root.output}"
                else
                    return root.message
                end
            else
                return ex.message
            end
        end

        private
        def extract_return_code(cmd_result)
            return cmd_result.return_code unless cmd_result.exception && cmd_result.status == CommandResult::FAILURE

            ex = cmd_result.exception
            if ex.is_a?(ActivityFatalError) && ex.root_exception
                root = ex.root_exception
                if root.respond_to?(:exit_code)
                    return root.exit_code
                else
                    return 1
                end
            else
                ex.respond_to?(:exit_code) ? ex.exit_code : 1
            end
        end

        private
        def write_through_tmp_file(dst_file, data)

            # first write to temp file
            tmp_file = Tempfile.new 'healthd'
            tmp_file.write data
            tmp_file.chmod 0644
            tmp_file.close

            FileUtils.mv tmp_file.path, dst_file
        end

        private
        def truncate(str)
            return unless str
            return str if (str.length + @@truncation_message.length) <= @@max_message_length

            end_index = @@max_message_length - @@truncation_message.length - 1

            last_sentence = str[0..end_index].rindex(/[\n\r.]/) || 0
            str[0..last_sentence].strip + @@truncation_message
        end
    end
end
