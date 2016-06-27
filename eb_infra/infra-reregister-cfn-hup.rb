# Beanstalk

require 'logger'
require 'executor'

require 'elasticbeanstalk/cfn-wrapper'
require 'elasticbeanstalk/command-processor'
require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/utils'

DEFAULT_CHECK_INTERVAL = 5

def reregister(metadata:, main_pid:, logger:, check_interval:DEFAULT_CHECK_INTERVAL)
    # wait for some time to make sure we have ensure we have sent a success signal
    logger.info "Waiting for command-processor process #{main_pid} to exit..."
    loop do
        begin
            Process.getpgid(main_pid)
        rescue Errno::ESRCH
            break;  # main process exits
        end

        Kernel.sleep(check_interval)
    end
    logger.info "command-processor process #{main_pid} exited."
    Kernel.sleep(check_interval)    # postpone further for cfn-hup finish its communication

    environment_stack_id = metadata.environment_stack_id  
    metadata.stack_name = environment_stack_id
    metadata.write_config_file
    logger.info "Updated config file with new stack name #{environment_stack_id}."

    metadata.clear_metadata_cache
    logger.info 'Cleared metadata cache.'

    ElasticBeanstalk::CfnWrapper.update_cfn_hup_conf(stack_name: environment_stack_id, url: metadata.cfn_url)
    logger.info 'Updated cfn-hup.conf.'

    Executor::Exec.sh(%Q[restart cfn-hup LANG=#{ENV['LANG']} || start cfn-hup LANG=#{ENV['LANG']}])
    logger.info 'Restarted cfn-hup.'
    
    Kernel.exit
rescue => e
    logger.error(e.message)
    Kernel.abort(e.message)
end


logger = Logger.new($stderr)
logger.formatter = ElasticBeanstalk::Utils.logger_formatter
metadata = ElasticBeanstalk::EnvironmentMetadata.new(logger: logger)

# get new stack name from cfn
environment_stack_id = metadata.environment_stack_id
logger.debug("Original Stack ID is '#{environment_stack_id}'.")
raise 'Environment Stack ID not found' if environment_stack_id.nil? || environment_stack_id.empty?

# use a background job so we can signal success for command
main_pid = Process.pid
sub_pid = Kernel.fork do
    begin
        Process.daemon
        reregister(metadata: metadata,
                   main_pid: main_pid,
                   logger: CommandProcessor.logger)
    rescue => e
        logger.warn "Failed to re-register cfn-hup: (#{e.class}) #{e.message}."
    end
end
logger.info "Launched background process #{sub_pid} to re-register cfn-hup."
