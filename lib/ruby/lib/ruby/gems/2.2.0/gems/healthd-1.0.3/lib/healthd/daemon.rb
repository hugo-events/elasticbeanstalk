require 'healthd/daemon/options'
require 'healthd/daemon/logger'
require 'healthd/daemon/version'
require 'healthd/daemon/exceptions'
require 'healthd/daemon/queues'
require 'healthd/daemon/batch_processor'
require 'healthd/daemon/endpoint'
require 'healthd/daemon/environment'
require 'healthd/daemon/plugins/manager'

module Healthd
    module Daemon
        def self.init(services: true)
            # ensure that group id is set
            Environment.group_id

            # abort the daemon on any unhandled exception
            Thread.abort_on_exception = true

            Logger.unknown %[healthd daemon #{VERSION} initialized]

            if services
                # start the batch processor
                Healthd::Daemon::BatchProcessor.start

                # find all available plugins and start them
                Healthd::Daemon::Plugins::Manager.locate_plugins
                Healthd::Daemon::Plugins::Manager.execute!
            end
        end
    end
end
