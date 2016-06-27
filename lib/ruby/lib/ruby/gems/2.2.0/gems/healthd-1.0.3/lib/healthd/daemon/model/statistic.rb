require 'oj'

module Healthd
    module Daemon
        module Model
            module Statistic
                def self.create(namespace:, timestamp:, data:)
                    {
                        :id        => nil,
                        :namespace => namespace,
                        :timestamp => timestamp.to_i,
                        :data      => Oj.dump(data)
                    }
                end
            end
        end
    end
end
