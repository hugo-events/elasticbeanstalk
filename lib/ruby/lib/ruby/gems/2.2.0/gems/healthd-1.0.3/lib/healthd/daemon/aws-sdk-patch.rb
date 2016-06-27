require 'aws-sdk-core'

class Seahorse::Client::NetHttp::ConnectionPool::ExtendedSession
    def initialize(http)
        super(http)
        @http = http
        @http.keep_alive_timeout = Healthd::Daemon::Service::KEEP_ALIVE_TIMEOUT
    end
end
