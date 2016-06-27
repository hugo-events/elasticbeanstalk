require 'healthd/daemon/logger'
require 'healthd/daemon/model/statistic'
require 'timeout'

module Healthd
    module Daemon
        module Plugins
            class BatchBase
                @@queue = Queues::Batch
                @@logger = Logger

                @namespace = nil

                attr_reader :name, :queue, :continue, :logger, :options

                def initialize(queue: @@queue, logger: @@logger, continue: nil, options:)
                    @queue = queue
                    @logger = logger
                    @options = options
                    @continue = continue
                    @name = self.class.name

                    raise Exception, %[@namespace has to be defined by the plugin] unless namespace

                    logger.info %[loaded plugin: #{name}]
                end

                # Configure the plugin
                def setup
                end

                def collect
                    raise Exception, %[#collect has to be implemented by the plugin]
                end

                protected
                def namespace
                    self.class.namespace
                end

                protected
                def self.namespace(value=nil)
                    @namespace = value if value
                    @namespace
                end
            end
        end
    end
end
