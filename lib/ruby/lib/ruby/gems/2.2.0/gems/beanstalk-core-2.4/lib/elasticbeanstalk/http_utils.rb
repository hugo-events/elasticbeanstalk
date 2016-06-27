require 'net/http'
require 'elasticbeanstalk/utils'

module ElasticBeanstalk
    module HttpUtils
        class Non200StatusError < RuntimeError
            attr_accessor :response
            def initialize(message:, response:)
                super(message)
                @response = response
            end
        end

        @@default_open_timeout = 60
        @@default_read_timeout = 600
        @@default_max_retries = 5

        MAX_RETRY_SLEEP = 60

        def self.download(source_uri:, open_timeout: @@default_open_timeout,
                          read_timeout: @@default_read_timeout, max_retries: @@default_max_retries, &block)
            attempt = 0
            begin
                retriable_download(source_uri: source_uri, open_timeout: open_timeout, read_timeout: read_timeout, &block)
            rescue
                if attempt < max_retries
                    attempt += 1
                    backoff = Utils.random_backoff(attempt)
                    sleep backoff

                    retry
                else
                    raise
                end
            end
        end

        def self.download_to(source_uri:, destination:, open_timeout: @@default_open_timeout, read_timeout: @@default_read_timeout, max_retries: @@default_max_retries)
            download(source_uri: source_uri, open_timeout: open_timeout, read_timeout: read_timeout, max_retries: max_retries) do |response|
                open(destination, 'w') do |file|
                    write_response(response, file)
                end
            end
        end

        private
        def self.retriable_download(source_uri:, open_timeout:, read_timeout:)
            uri = URI(source_uri)
            use_ssl = uri.scheme == 'https'

            contents = nil
            Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl, open_timeout: open_timeout, read_timeout: read_timeout) do |http|
                request = Net::HTTP::Get.new(uri)

                http.request(request) do |response|
                    if response.code != '200'
                        message = "HTTP download failed. Response code: #{response.code}, message: #{response.message}"
                        raise Non200StatusError.new(message: message, response: response)
                    end

                    if block_given?
                        yield response
                    else
                        io = StringIO.new
                        write_response(response, io)
                        io.flush
                        contents = io.string
                    end
                end
            end

            contents
        end

        private
        def self.write_response(response, io)
            response.read_body do |chunk|
                io.write chunk
            end
        end
    end
end
