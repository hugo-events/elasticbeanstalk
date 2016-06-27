require 'healthd-appstat/plugin'

module Healthd
    module Plugins
        module Appstat
            def self.create(**options)
                Plugin.new **options
            end
        end
    end
end
