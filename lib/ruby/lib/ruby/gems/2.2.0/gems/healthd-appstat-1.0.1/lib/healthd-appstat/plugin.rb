require 'healthd/daemon/exceptions'
require 'healthd/daemon/logger'
require 'healthd/daemon/plugins/batch_base'
require 'healthd/daemon/model/statistic'
require 'healthd-appstat/log_file'
require 'healthd-appstat/http_status_counters'
require 'x-digest'
require 'chainsaw'

module Healthd
    module Plugins
        module Appstat
            class Plugin < Daemon::Plugins::BatchBase
                namespace "application"

                @@pattern = %["]
                @@units = %w[sec usec]
                @@timestamp_on_values = %w[completion arrival]
                @@unit = @@units.first
                @@timestamp_on = @@timestamp_on_values.first

                attr_accessor :path, :xdigest, :status_counters, :mode, :interval

                # don't use kwargs to workaround bugs in 2.2.2
                # - https://bugs.ruby-lang.org/issues/11091
                # - https://bugs.ruby-lang.org/issues/10693
                def initialize(**base_options)
                    path = base_options.delete(:path) { nil }
                    unit = base_options.delete(:unit) { nil }
                    timestamp_on = base_options.delete(:timestamp_on) { nil }
                    mode = base_options.delete(:mode) { 'follow' }
                    interval = base_options.delete(:interval) { nil }
                    pattern = base_options.delete(:pattern) { nil }
                    ext = base_options.delete(:ext) { true }

                    super base_options

                    @path = path || ENV['HEALTHD_APPSTAT_LOG'] || options.appstat_log_path
                    @unit = unit || options.appstat_unit || @@unit
                    @timestamp_on = timestamp_on || options.appstat_timestamp_on || @@timestamp_on
                    @mode = mode
                    @pattern = pattern || @@pattern
                    @interval = interval || @queue.collection_interval
                    @xdigest = XDigest.create :compression => 25
                    @status_counters = HTTPStatusCounters.new

                    unless @@units.include? @unit
                        raise Healthd::Exceptions::FatalError, %[invalid unit: "#{@unit}". supported units: #{@@units.join ', '}]
                    end

                    unless @@timestamp_on_values.include? @timestamp_on
                        raise Healthd::Exceptions::FatalError, %[invalid timestamp-on value: "#{@timestamp_on}". supported values: #{@@timestamp_on_values.join ', '}]
                    end

                    @usec = (@unit == 'usec')
                    @arrival = (@timestamp_on == 'arrival')

                    # sample log format for nginx:
                    #
                    #   log_format healthd '$msec"$uri"'
                    #                   '$status"$request_time"$upstream_response_time"'
                    #                   '$http_x_forwarded_for';
                    #
                    #   if ($time_iso8601 ~ "^(\d{4})-(\d{2})-(\d{2})T(\d{2})") {
                    #     set $year $1;
                    #     set $month $2;
                    #     set $day $3;
                    #     set $hour $4;
                    #   }
                    #
                    #   access_log /var/log/nginx/healthd/application.log.$year-$month-$day-$hour healthd;
                    @chainsaw = Chainsaw.create :separator  => @@pattern, 
                                                :transforms => [:fixnum, nil, nil, :float], 
                                                :ext        => ext
                end

                def collect
                    each_timeslot do |timestamp, stats|
                        statistic = Daemon::Model::Statistic.create :namespace => namespace, 
                                                                    :timestamp => timestamp, 
                                                                    :data      => stats
                        queue.enq statistic

                        logger.debug { %[#{name}: #{statistic.inspect}] }
                    end
                end

                def each_timeslot
                    count = nil
                    previous_timeslot = 0

                    LogFile.open(path, :mode => mode) do |io|
                        @chainsaw.cut(io) do |epoch, request, status, latency, upstream_latency, x_forwarded_for|
                            unless x_forwarded_for
                                logger.warn %[partial line read from "#{io.path}". skipping]
                                next
                            end

                            # normalize units to seconds with millisecond resolution
                            if @usec
                                latency = (latency / 1_000_000.0).round(3)
                                # upstream_latency = (upstream_latency / 1_000_000).round(3)
                            end

                            # normalize timestamp to request completion time
                            if @arrival
                                epoch += latency
                            end

                            timeslot = epoch.div(interval) * interval + interval
                            if timeslot > previous_timeslot   # e.g. nginx timestamps are not monotonic
                                if count
                                    stats = {
                                        'duration'          => interval,
                                        'latency_histogram' => xdigest.export(:round => 5), 
                                        'http_counters'     => status_counters.to_h
                                    }

                                    yield previous_timeslot, stats
                                end

                                count = 0
                                xdigest.clear
                                status_counters.clear
                                previous_timeslot = timeslot
                            end

                            count += 1
                            xdigest.add latency
                            status_counters << status
                        end
                    end
                end
            end
        end
    end
end
