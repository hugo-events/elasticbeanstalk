require 'logger'
require 'healthd/daemon/options'

module Healthd
    module Daemon
        log_path = Options.log_device? ? (ENV['HEALTHD_DAEMON_LOG'] || Options.log_path) : STDOUT

        Logger = ::Logger.new log_path

        # set default log level
        #
        # DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN
        Logger.level = case
        when Options.debug
            ::Logger::DEBUG
        when Options.verbose
            ::Logger::INFO
        else
            ::Logger::WARN
        end
    end
end
