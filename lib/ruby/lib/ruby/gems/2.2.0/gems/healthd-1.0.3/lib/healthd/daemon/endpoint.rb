require 'sinatra/base'
require 'json'
require 'healthd/daemon/endpoint_common'

module Healthd
    module Daemon
        class Endpoint < Sinatra::Base
            register EndpointCommon
            helpers EndpointCommon

            initialize_common

            get '/status' do
                json :status => "ok"
            end

            post "/statistic" do
                refute_empty!

                Logger.info %[http /statistic: #{payload.inspect}]
                Queues::Batch.enq payload
            end
        end
    end
end
