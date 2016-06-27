require 'ostruct'
require 'yaml'

module Healthd
    module Daemon
        config_path = ENV['HEALTHD_CONFIG'] || '/etc/healthd/config.yaml'
        config = File.exists?(config_path) ? YAML.load_file(config_path) : {}

        Options = OpenStruct.new config

        Options.define_singleton_method :log_device? do
            Options.daemonize || Options.log_to_file
        end

        # defaults
        Options.quiet ||= false
        Options.verbose ||= false
        Options.debug ||= false
        Options.daemonize ||= false
        Options.log_to_file ||= false

        # paths
        Options.pid_path ||= "/var/run/healthd/daemon.pid"
        Options.log_path ||= "/var/log/healthd/daemon.log"
        Options.appstat_log_path ||= "/var/log/nginx/healthd/application.log"
        Options.beanstalk_base_path ||= "/var/elasticbeanstalk/healthd"
        Options.sqsd_base_path ||= "/var/run/aws-sqsd"

        # appstat
        Options.appstat_unit ||= 'sec' # usec
        Options.appstat_timestamp_on ||= 'completion' # arrival
    end
end
