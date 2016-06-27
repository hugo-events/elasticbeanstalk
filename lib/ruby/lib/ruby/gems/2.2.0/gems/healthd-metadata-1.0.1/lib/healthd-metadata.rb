require 'healthd-metadata/plugin'

module Healthd
    module Plugins
        module Metadata
            def self.create(**options)
                Plugin.new **options
            end
        end
    end
end
