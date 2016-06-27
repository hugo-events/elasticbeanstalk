require 'rack'
require 'rack/parser'
require 'healthd/daemon'
require 'logger'
require 'oj'

json_mimetype = 'application/json'
json_regexp = /^#{json_mimetype}$/
wildcard = ''

json_handler = Proc.new do |error, type|
    content_type = { 'Content-Type' => 'application/json' }
    body = { :error => error }.to_json

    [400, content_type, [body]]
end

json_parser = Proc.new do |body|
    begin
        Oj.load body, :symbol_keys => true   # TODO: JSON has friendlier error messages than Oj
    rescue => e
        Healthd::Daemon::Logger.warn %[invalid request: #{e.message}]
        raise
    end
end

unsupported_content_type = Proc.new do |body|
    Healthd::Daemon::Logger.warn %[unsupported content type]
    raise %["application/json" is the only supported content-type]
end

use Rack::Parser, :parsers  => { json_regexp => json_parser, wildcard => unsupported_content_type },
                  :handlers => { wildcard => json_handler }

require 'healthd/daemon/endpoint'
run Healthd::Daemon::Endpoint
