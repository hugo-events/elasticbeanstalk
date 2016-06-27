require 'aws-sdk'
require 'timeout'
require 'open-uri'
require 'socket'
require 'net/http'
require 'fileutils'
require 'tempfile'
require 'json'

# TCP:80
# HTTP:80/weather/us/wa/seattle
#
module AWS::EB::SQSD::CloudWatchMonitor
    @@metric_namespace = 'ElasticBeanstalk/SQSD'
    @@metric_name = 'Health'
    @@cloudwatch_metric_interval = 60 # seconds
    @@healtcheck_protocols = %w[http tcp]
    @@healthd_marker_file = '/var/run/aws-sqsd/fault.json'

    def monitor
        # initialize to true so we don't skip polling before first health check happens
        # (just to be safe, we are calling check_health immediately afterwards)
        @is_healthy = true

        # first health check
        @is_healthy, @fault_mode_cause, @fault_mode_timestamp = check_health

        @cloud_watch = Aws::CloudWatch::Client.new :region => config.region
        @monitor_timer = EventMachine::PeriodicTimer.new(config.cloudwatch_interval || @@cloudwatch_metric_interval) do
            @is_healthy, @fault_mode_cause, @fault_mode_timestamp = check_health

            emit_metric(@is_healthy ? 1 : 0)
            update_healthd_marker_file
        end
    end

    def monitor_cleanup
        FileUtils.rm_f @@healthd_marker_file
    end

    def is_healthy?
        @is_healthy
    end

    private
    def emit_metric(health)
        metric_options = {
            :namespace => @@metric_namespace, 
            :metric_data => [
                {
                    :metric_name => @@metric_name, 
                    :value => health, 
                    :dimensions => [
                        { :name => 'EnvironmentName', :value => config.environment_name }
                    ]
                }
            ]
        }

        log 'metrics', %[emitting instance health: #{health}] if config.verbose
        try(log_category: "metrics", :retries => 0) do
            @cloud_watch.put_metric_data metric_options
        end
    end

    private
    def check_health
        ok = false
        protocol, port, path = nil, nil, nil
        cause = nil
        timestamp = Time.new.to_i

        try(log_category: "metrics", :retries => 0) {
            protocol, port, path = parse_healthcheck config.healthcheck
        }

        if path
            uri = URI "#{protocol}://localhost:#{port}#{path}"
            begin
                # timeout
                #
                code = Net::HTTP.get_response(uri).code
                if code == "200"
                    ok = true
                else
                    cause = %[service healthcheck to URL "#{uri}" failed with http status code "#{code}"]
                    log 'healthcheck-err', cause
                end
            rescue Exception => e
                cause = %[service healthcheck failed with error: #{e.message}]
                log 'healthcheck-err', cause
            end
        else
            begin
                socket = TCPSocket.new 'localhost', port
                ok = true
            rescue Exception => e
                cause = %[service healthcheck failed with error: #{e.message}]
                log 'healthcheck-err', cause
            ensure
                socket.close if socket && ! socket.closed?
            end
        end

        unless @successful_sqs_poll
            cause = %[failed to pull messages from SQS queue with error: #{@sqs_last_error_message}]
            log 'healthcheck-err', cause
        end

        ok = ok && @successful_sqs_poll
        return ok, cause, timestamp
    end

    private
    def parse_healthcheck(target)
        protocol, port, path = target.scan(/(.+?):([0-9]+)(.*)/).first

        unless protocol && protocol
            raise AWS::EB::SQSD::FatalError, %[invalid healthcheck target "#{target}"]
        end

        path = nil if path && path.empty?
        protocol = protocol.downcase if protocol

        unless @@healtcheck_protocols.include? protocol
            raise AWS::EB::SQSD::FatalError, %[invalid protocol "#{protocol}". supported protocols are: #{@@healtcheck_protocols.join ' '}]
        end

        if protocol == 'tcp' && path
            raise AWS::EB::SQSD::FatalError, %[invalid healthcheck. path is only supported with 'http']
        end

        return [protocol, port, path]
    end

    private
    def update_healthd_marker_file
        if @is_healthy      # regardless of transition, simply make sure the marker file is gone
            FileUtils.rm_f @@healthd_marker_file
            return
        end

        # create the marker file if it's not there
        # (otherwise it is an indication of a previous health check failure, in which case we keep the oldest failure)
        atomic_json_dump @@healthd_marker_file, { :cause => @fault_mode_cause, :timestamp => @fault_mode_timestamp } unless File.exists? @@healthd_marker_file
    end

    private
    def atomic_json_dump(filename, obj, perm: 0644)
        f = Tempfile.open(File.basename(filename)) { |f| f.write obj.to_json; f }

        File.chmod perm, f.path
        FileUtils.mv f.path, filename
    end
end
