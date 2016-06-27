module Healthd
    module Daemon
        module EndpointCommon
            def initialize_common
                set :logging, nil
                set :show_exceptions, false
                set :raise_errors, false

                before do
                    content_type 'application/json'
                end

                not_found do
                    Logger.warn %[invalid request path "#{request.path}"]
                    json_error 'Not Found', :status => 404
                end

                error do
                    Logger.warn %[request path "#{request.path}" error: #{env['sinatra.error'].message}]
                    json_error env['sinatra.error'].message, :status => 500
                end
            end

            private
            def json(document, status: 200)
                halt status, document.to_json
            end

            private
            def json_error(error, status:)
                Logger.debug %[invalid request to "#{request.path}": "#{error}", http status: #{status}]

                document = { :error => error }
                json document, :status => status
            end

            private
            def payload
                params
            end

            private
            def refute_empty!
                request.body.rewind

                if request.body.read == ""
                    json_error %[body of the request is empty], :status => 400
                end
            end
        end
    end
end
