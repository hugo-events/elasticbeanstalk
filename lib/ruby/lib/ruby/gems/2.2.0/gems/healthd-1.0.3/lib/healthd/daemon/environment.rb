require 'uri'
require 'net/http'
require 'oj'
require 'aws-sdk-core'
require 'ostruct'
require 'time'
require 'healthd/daemon/options'
require 'healthd/daemon/logger'
require 'healthd/daemon/exceptions'

module Healthd
    module Daemon
        module Environment
            class InvalidHTTPResponse < RuntimeError; end

            @@instance_id_url = URI 'http://169.254.169.254/latest/dynamic/instance-identity/document'
            @@instance_id_timeout = 1
            @@instance_id_retry_interval = 3
            @@retries = 30

            def self.metadata
                @@instance_metadata ||= begin
                    http = Net::HTTP.new @@instance_id_url.host
                    http.open_timeout = @@instance_id_timeout
                    http.read_timeout = @@instance_id_timeout

                    begin
                        response = http.request_get @@instance_id_url.path
                        if response.code.to_i == 200
                            document = Oj.load response.body
                            document = document.collect do |key, value|
                                key_sym = Seahorse::Util.underscore(key).to_sym
                                [key_sym, value]
                            end.to_h

                            OpenStruct.new document
                        else
                            raise InvalidHTTPResponse
                        end
                    rescue => e
                        if (@@retries -= 1) >= 0
                            Logger.warn %[failed to retrieve EC2 instance metadata. retrying. #{@@retries} left]
                            sleep @@instance_id_retry_interval
                            retry
                        else
                            raise Exceptions::FatalError, %[failed to retrieve EC2 instance metadata]
                        end
                    end
                end
            end

            def self.instance_id
                Options.instance_id || metadata.instance_id
            end

            def self.availability_zone
                Options.availability_zone || metadata.availability_zone
            end

            def self.region
                Options.region || metadata.region
            end

            def self.launch_time
                @@instance_launch_time ||= begin
                    time = Options.pending_time || metadata.pending_time
                    Time.parse time if time
                end
            end

            def self.group_id
                if group_id = Options.group_id
                    group_id
                else
                    raise Exceptions::FatalError, %[group id is required]
                end
            end
        end
    end
end
