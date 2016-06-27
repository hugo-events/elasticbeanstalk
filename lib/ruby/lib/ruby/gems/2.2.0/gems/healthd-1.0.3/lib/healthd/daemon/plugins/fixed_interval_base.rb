require 'healthd/daemon/logger'
require 'healthd/daemon/model/statistic'
require 'healthd/daemon/plugins/batch_base'
require 'timeout'

module Healthd
    module Daemon
        module Plugins
            class FixedIntervalBase < BatchBase
                @@measurement_window = 0.1

                @data_expected = true

                attr_reader :fixed_sleep
                attr_accessor :previous_deadline_at, :deadline_at

                def initialize(**options)
                    super **options

                    @measurement_window = @@measurement_window
                    @fixed_sleep = @queue.collection_interval - @queue.synchronization_threshold
                    @previous_deadline_at = nil
                    @deadline_at = nil
                end

                # Changes the timeout value if value is specified. Returns timeout
                def measurement_window(value=nil)
                    if value
                        raise %[measurement window has 0.0 - 1 seconds] unless (0.0..1).include? value
                        @measurement_window = value
                    end
                    @measurement_window
                end

                # == Usage
                #
                # Change the default options, e.g. to change the measurement window to 250 ms
                #
                #   def setup
                #       measurement_window 0.25
                #   end
                def setup
                end

                # Data collector. Returns a Hash
                #
                # Has to be implemented by the plugin
                def snapshot
                    raise Exception, %[#snapshot has to be implemented by the plugin]
                end

                def collect
                    each_deadline do
                        data = snapshot

                        if data && !data.empty?
                            statistic = Model::Statistic.create :namespace => namespace, 
                                                                :timestamp => deadline_at, 
                                                                :data      => data
                            queue.enq statistic

                            Logger.debug { %[#{name}: #{statistic.inspect}] }
                        else
                            Logger.warn { %[#{name}: no data available] } if data_expected?
                        end
                    end
                end

                protected
                def data_expected?
                    self.class.data_expected
                end

                protected
                def self.data_expected(value=nil)
                    @data_expected = value if value
                    @data_expected
                end

                private
                def each_deadline
                    loop do
                        loop do
                            self.deadline_at = queue.processed_at

                            break if deadline_at != previous_deadline_at
                            sleep 0.1
                        end

                        sync_delay = deadline_at - Time.now - measurement_window
                        if sync_delay > 0
                            Logger.debug { %[#{name}: sleeping for #{sync_delay.round(2)} seconds] }
                            sleep sync_delay
                        end
                    
                        yield

                        if Time.now > deadline_at
                            delta = Time.now - deadline_at

                            Logger.info { %[#{name}: missed the deadline by #{delta.round(2)} seconds] }

                            adjusted_sleep = fixed_sleep - delta
                            adjusted_sleep = 0 if adjusted_sleep < 0

                            sleep adjusted_sleep
                        else
                            sleep fixed_sleep
                        end
                        self.previous_deadline_at = deadline_at

                        break if continue && ! continue.call
                    end
                end
            end
        end
    end
end
