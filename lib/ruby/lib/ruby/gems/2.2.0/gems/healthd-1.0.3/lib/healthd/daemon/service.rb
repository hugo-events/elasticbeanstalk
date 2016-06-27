require 'healthd/daemon/options'
require 'healthd/daemon/logger'
require 'healthd/daemon/environment'
require 'aws-sdk-core'
require 'healthd/daemon/aws-sdk-patch'

module Healthd
    module Daemon
        module Service
            KEEP_ALIVE_TIMEOUT = 30

            @@connections_recycled_after = 1800 + (1800 * rand)
            @@connections_recycled_at = Time.now

            def self.client
                @@client ||= begin
                    define_service

                    region = Options.region || Environment.region
                    endpoint = Options.endpoint || "https://elasticbeanstalk-health.#{region}.amazonaws.com/"

                    config = {}
                    config[:region] = region
                    config[:sigv4_region] = region
                    config[:endpoint] = endpoint
                    config[:ssl_verify_peer] = true
                    config[:validate_params] = false
                    config[:convert_params] = true
                    config[:retry_limit] = 1
                    config[:http_open_timeout] = 5
                    config[:http_read_timeout] = 5
                    config[:http_idle_timeout] = KEEP_ALIVE_TIMEOUT

                    if Options.debug
                        config[:logger] = Logger
                        config[:log_formatter] = Seahorse::Client::Logging::Formatter.colored
                        config[:http_wire_trace] = true
                        config[:validate_params] = true
                    end

                    Aws::Healthd::Client.new config
                end

                if Time.now - @@connections_recycled_at > @@connections_recycled_after
                    Logger.debug do
                        connection_count = Seahorse::Client::NetHttp::ConnectionPool.pools.collect(&:size).reduce(&:+)
                        %[recycling #{connection_count} connection(s) after #{@@connections_recycled_after} seconds]
                    end
                    Seahorse::Client::NetHttp::ConnectionPool.pools.collect(&:empty!)
                    @@connections_recycled_at = Time.now
                end
                @@client
            end

            def self.define_service
                return if defined? Aws::Healthd

                healthd_description = {
                  :api => "#{Dir.pwd}/config/api.json"
                }
                Aws.add_service 'Healthd', healthd_description
            end
        end
    end
end
