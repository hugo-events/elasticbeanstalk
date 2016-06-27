module Healthd
    module Daemon
        # add accessor to Thread::Queue to track when the queue is next processed
        # Used by like Plugins::FixedIntervalBase to determine when to fire #snapshot
        class BatchQueue < Thread::Queue
            attr_accessor :processed_at, :collection_interval, :synchronization_threshold

            def initialize
                @collection_interval = 10
                @synchronization_threshold = @collection_interval / 2
                @processed_at = Time.now + @collection_interval

                super
            end
        end

        module Queues
            Batch = BatchQueue.new
        end
    end
end