require 'timeout'
require 'healthd/daemon/logger'
require 'healthd/daemon/service'
require 'healthd/daemon/environment'
require 'healthd/daemon/exceptions'

module Healthd
    module Daemon
        module BatchProcessor
            include Timeout

            @@name = self.name
            @@batch_limit = 20
            @@backlog_limit = 400
            @@message_expiration = 30 * 60
            @@container_version = 1

            @@validation_error = 'ValidationError'
            @@internal_error = 'InternalFailure'
            @@contains_duplicates = 'contains duplicates'

            def self.start(interval: nil, sync_threshold: nil)
                Logger.debug "#{@@name} initialized"

                Thread.new do
                    interval ||= Queues::Batch.collection_interval
                    sync_threshold ||= Queues::Batch.synchronization_threshold
                    last_target_time = Time.now
                    messages = []

                    loop do
                        begin
                            begin
                                target_time = last_target_time + interval
                                until_target_time = target_time - Time.now

                                if until_target_time < sync_threshold / 2.0
                                    Logger.debug { "missed a collection deadline. collecting in #{interval} seconds" }

                                    target_time = Time.now + interval
                                    until_target_time = target_time - Time.now
                                end
                                Queues::Batch.processed_at = target_time

                                timeout(until_target_time) do
                                    loop do
                                        messages << Queues::Batch.deq
                                    end
                                end
                            rescue Timeout::Error; end

                            process_batch messages if messages.any?
                            last_target_time = target_time

                            break if block_given? && yield
                        rescue Exceptions::FatalError
                            raise
                        rescue => e
                            Logger.error Healthd::Exceptions.format(e)
                        rescue Exception => e
                            Logger.fatal Healthd::Exceptions.format(e)
                            raise
                        end
                    end
                end
            end

            def self.process_batch(messages)
                begin
                    statistics_batch = messages.last @@batch_limit
                    ids_to_reprocess = post_batch statistics_batch

                    messages.pop statistics_batch.count
                    ids_to_reprocess.each do |id|
                        messages << statistics_batch[id]
                    end
                rescue Exceptions::FatalError, ArgumentError
                    raise
                rescue => e
                    Logger.warn %[sending message(s) failed: (#{e.class}) #{e.message}]
                end

                valid_messages, expired_messages = messages.partition do |i|
                    Time.now.to_i - i[:timestamp] < @@message_expiration if i[:timestamp]
                end
                if expired_messages.any?
                    Logger.warn %[discarding #{expired_messages.count} expired or invalid message(s)]
                    messages.replace valid_messages
                end

                if messages.size > @@backlog_limit
                    truncate_count = messages.size - @@backlog_limit

                    Logger.warn %[too many unsent messages. discarding #{truncate_count} message(s)]

                    messages.shift truncate_count
                end
            end

            def self.post_batch(statistics_batch)
                statistics_batch.each_with_index { |element, index| element[:id] = index.to_s }

                begin
                    r = Service.client.put_instance_statistics :instance_id       => Environment.instance_id, 
                                                               :group_id          => Environment.group_id,
                                                               :container_version => @@container_version,
                                                               :client_version    => VERSION,
                                                               :statistics        => statistics_batch
                rescue Aws::Healthd::Errors::InvalidRequestException => e
                    if e.message[@@contains_duplicates]
                        Logger.warn %[discarding #{statistics_batch.size} statistic items. request contains duplicates]
                        return []
                    end
                    raise
                end

                Logger.info { %[posted #{statistics_batch.count - r.unprocessed_items.count} statistic(s)] }
                items_to_reprocess = r.unprocessed_items.select do |i|
                    invalid_item = i.id ? statistics_batch[i.id.to_i] : 'unknown'

                    case i.error_code
                    when @@internal_error
                        true
                    when @@validation_error
                        Logger.warn %[discarding statistic item after validation error (#{i.message}): #{invalid_item}]
                        false
                    else
                        Logger.warn %[unknown unprocessed items error code "#{i.error_code}" for item: #{invalid_item}]
                        false
                    end
                end

                ids_to_reprocess = items_to_reprocess.collect { |i| i.id.to_i }.compact
                if ids_to_reprocess.any?
                    Logger.warn %[reprocessing #{ids_to_reprocess.count} message(s) due to service internal error]
                end
                ids_to_reprocess
            end
        end
    end
end
