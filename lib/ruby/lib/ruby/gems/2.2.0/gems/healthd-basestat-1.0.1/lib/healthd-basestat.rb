require 'healthd-basestat/plugin'

module Healthd
    module Plugins
        module Basestat
            def self.create(**options)
                Plugin.new **options
            end
        end
    end
end
