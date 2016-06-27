module Healthd
    module Plugins
        module Appstat
            class HTTPStatusCounters
                def initialize
                    clear
                end

                def clear
                    @data = {}
                    @data.default = 0

                    @key_cache = {}
                end

                def <<(code)
                    key = @key_cache[code]
                    key = @key_cache[code] = "status_#{code}" unless key

                    @data[key] += 1
                    @data['request_count'.freeze] += 1
                end

                def to_h
                    @data
                end
            end
        end
    end
end
