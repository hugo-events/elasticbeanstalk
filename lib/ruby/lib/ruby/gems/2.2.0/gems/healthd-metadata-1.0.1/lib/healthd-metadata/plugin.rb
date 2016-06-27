require 'healthd/daemon/environment'
require 'healthd/daemon/plugins/batch_base'
require 'healthd/daemon/logger'

module Healthd
    module Plugins
        module Metadata
            class Plugin < Daemon::Plugins::BatchBase
                namespace 'metadata'

                @collection_interval = 24 * 60 * 60

                def collect
                    loop do
                        statistic = Daemon::Model::Statistic.create :namespace => namespace, 
                                                                    :timestamp => queue.processed_at, 
                                                                    :data      => metadata

                        queue.enq statistic
                        logger.debug { %[#{name}: #{statistic.inspect}] }
                        statistic = nil

                        break if continue && ! continue.call
                        sleep collection_interval
                    end
                end

                def metadata
                    {
                        'launch_time'       => Healthd::Daemon::Environment.launch_time.to_i,
                        'availability_zone' => Healthd::Daemon::Environment.availability_zone
                    }
                end

                private
                def collection_interval
                    self.class.collection_interval
                end

                private
                def self.collection_interval
                    @collection_interval
                end
            end
        end
    end
end
