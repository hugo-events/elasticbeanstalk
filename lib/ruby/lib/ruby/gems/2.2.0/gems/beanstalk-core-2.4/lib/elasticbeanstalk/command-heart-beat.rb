
#==============================================================================
# Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#       https://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#==============================================================================

require 'logger'
require 'json'
require 'thread'

require 'executor'

require 'elasticbeanstalk/activity'
require 'elasticbeanstalk/cfn-wrapper'
require 'elasticbeanstalk/environment-metadata'
require 'elasticbeanstalk/utils'


module ElasticBeanstalk

    class  CommandHeartBeatReporter

        #
        # CommandHeartBeatReporter sends heart beat to control plane during command execution.
        # It collects progress status from Activity including finished activities and ongoing activity,
        # and events.
        #
        # For each report_interval time, it will wake up and collect new history from last time and report.
        # It will exit when reaches timeout.
        #
        #
        #
        #
        #
        DEFAULT_TIMEOUT = 1800          # 1800 seconds
        DEFAULT_REPORT_INTERVAL = 30    # report every 30 seconds
        DATA_SIZE = 800                 # pay load size limit 1k, 800 to be safe
        @@history_file = '/var/log/act-history.log'

        #
        #
        #
        def initialize (exit_signal_queue:, timeout: DEFAULT_TIMEOUT, report_interval: DEFAULT_REPORT_INTERVAL,
                        logger: Logger.new(File.open(File::NULL, "w")))

            @logger = logger
            @env_metadata = EnvironmentMetadata.new(logger: logger)

            history_index = 0
            start_time = Time.now
            # run until timeout or signaled
            while (Time.now - start_time < timeout)

                # Collect activity history from last report
                activities = []
                history = Activity.class_variable_get(:@@activity_history)
                if (history.length > history_index)
                    for index in history_index ... history.length
                        activities << history[index]
                    end
                end
                history_index = history.length

                @logger.info('Sending heart beat report.')
                report generate_activity_reports(timestamp: Time.now, activities: activities)

                if ! exit_signal_queue.empty?
                    # stop polling if being signaled
                    break
                end
                sleep(report_interval)
            end

            if exit_signal_queue.empty?
                @logger.info('Timed out for sending report. Exiting CommandHeartBeatReporter.')
            else
                @logger.info('Received exit signal. Exiting CommandHeartBeatReporter.')
            end
        end


        private
        def generate_activity_reports(timestamp:, activities:)
            # we will generate an array of activity arrays
            # to accommodate the payload size limit
            activity_arrays = []
            activity_array = []

            activities.each do |activity|
                activity_array << {"timestamp" => activity.timestamp.to_ms, "message" => activity.message}

                # if the JSON representation of the current array of activities
                # is too large, drop the last activity and put it into a new array
                offset_length = JSON.generate(activity_array).length - DATA_SIZE

                if offset_length > 0
                    if activity_array.length == 1
                        # if the single message is too large to fit in, truncate it with an error log
                        @logger.warn("Truncating too large Activity message: '#{activity_array[0].inspect}'")
                        activity_array[0]['message'] = activity_array[0]['message'][0...-offset_length]
                        activity_arrays << activity_array
                        activity_array = []
                    else
                        activity_arrays << activity_array[0...-1]
                        activity_array = []
                        redo
                    end
                end
            end
            activity_arrays << activity_array

            reports = []
            # generate reports from array of activity arrays
            activity_arrays.each do |activity_array|
                reports << {
                    'time' => timestamp.to_ms,
                    'type' => 'CmdHeartBeat',
                    'data' => {
                        'activities' => activity_array
                    }
                }
            end
            reports
        end

        private
        def report(reports)
            # f = File.new(@@history_file, "a")

            # reports.each do |report|
            #     # f.write("#{JSON.pretty_generate(report)}\n")
            #     send_heartbeat_report(report)
            # end

            # f.close
        end

        private
        def send_heartbeat_report(report)
        end
    end

end
