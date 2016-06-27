module Healthd
    module Exceptions
        class FatalError < ::RuntimeError; end
        class RuntimeError < ::RuntimeError; end
        class PluginRuntimeError < ::RuntimeError; end

        def self.format(e)
            first_trace = e.backtrace.first
            backtrace = e.backtrace.drop(1).collect { |i| "\tfrom #{i}"}.join("\n")
            message = %[#{first_trace}: #{e.message} (#{e.class})\n#{backtrace}]

            while e.cause
                first_trace = e.cause.backtrace.first
                backtrace = e.cause.backtrace.drop(1).collect { |i| "\tfrom #{i}"}.join("\n")
                message = %[#{message}\ncaused by:\n#{first_trace}: #{e.cause.message} (#{e.cause.class})\n#{backtrace}]

                e = e.cause
            end
            %[#{message}\n]
        end
    end
end
