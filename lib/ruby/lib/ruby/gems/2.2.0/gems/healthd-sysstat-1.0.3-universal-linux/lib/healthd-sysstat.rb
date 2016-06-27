require 'healthd-sysstat/plugin'

module Healthd
    module Plugins
        module Sysstat
            def self.create(**options)
                Plugin.new **options
            end
        end
    end
end
