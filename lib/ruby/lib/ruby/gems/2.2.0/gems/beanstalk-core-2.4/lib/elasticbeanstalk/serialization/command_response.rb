
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

require 'elasticbeanstalk/constants'
require 'elasticbeanstalk/event'
require 'elasticbeanstalk/exceptions'

module ElasticBeanstalk
    class CommandResponse
        MAX_OVERALL_RESULT_SIZE = 1024

        def self.generate(cmd_result:, api_version:)
            response = CommandResponse.new(cmd_result: cmd_result)
            begin
                mod = CommandResponse.const_get("SerializerV#{api_version.to_s.gsub(/\./, '_')}")
                response.extend mod
            rescue NameError # raised from const_get
                raise BeanstalkRuntimeError, %[Not supported command API version #{@api_version}]
            end

            response.compile
        end

        def initialize(cmd_result:)
            @cmd_result = cmd_result
            @msg = cmd_result.msg.dup
            @events = @cmd_result.events.collect do |event|
                event.dup
            end
            @return_code = cmd_result.return_code
            @truncated = false
        end

        public
        def compile
            raise BeanstalkRuntimeError, 'Not implemented method'
        end

        # generate response string from @response object, used in truncate_events() and compile()
        private
        def serialize
            raise BeanstalkRuntimeError, 'Not implemented method'
        end

        # truncate events if message is too large. only events that are less than truncation_severity
        # will be deleted
        private
        def truncate_events(truncation_severity)
            return if @events.nil? || @events.empty?

            result_str = serialize
            if result_str.length > MAX_OVERALL_RESULT_SIZE && ! @events.empty?
                @events.sort! # sort events based on severity

                while ! @events.empty? && result_str.length > MAX_OVERALL_RESULT_SIZE \
                        && Event::severity_map[@events[0].severity] <= Event::severity_map[truncation_severity]
                    @truncated = true
                    @events.delete_at(0)    # remove one least severe event
                    result_str = serialize
                end
            end
        end


        module SerializerV1_0
            API_VERSION = '1.0'
            MAX_EVENT_MSG_SIZE = 512
            MAX_OUTPUT_MSG_SIZE = 256
            TIP_MESSAGE = ' For more detail, check /var/log/eb-activity.log using console or EB CLI' # no dot at the end
            TRUNCATION_TOKEN = '(TRUNCATED)...'

            def compile
                # shrink event messages when applicable
                @events.each do |event|
                    event.msg = event.msg[0 .. MAX_EVENT_MSG_SIZE - 1]
                end

                # compile message string from exception for failed command
                if @cmd_result.status == CommandResult::FAILURE
                    process_failure
                    @msg << TIP_MESSAGE
                else
                    @msg = ''
                end

                # assemble response
                results = {'status' => @cmd_result.status,
                           'msg' => @msg,
                           'returncode' => @return_code,
                           'events' => @events}

                @response = {'status' => @cmd_result.status,
                             'api_version' => API_VERSION,
                             'results' => [results]}

                if ! @cmd_result.config_sets.nil? && ! @cmd_result.config_sets.empty?
                    results['config_set'] = @cmd_result.config_sets
                end

                # truncate events if message doesn't fit
                truncate_events(:WARN)

                # truncate message if high severity events are too large
                if serialize.length > MAX_OVERALL_RESULT_SIZE
                    @truncated = true
                    diff = serialize.length - MAX_OVERALL_RESULT_SIZE # re-serialize to accommodate the "truncated" key
                    if diff > results['msg'].length
                        results['msg'] = ''
                    else
                        results['msg'] = results['msg'][-(results['msg'].length-diff)..-1]
                    end
                end

                # further truncate events if message still doesn't fit
                truncate_events(:FATAL)

                @events.sort! { |e1, e2| e1.timestamp <=> e2.timestamp }
                serialize
            end


            private
            def serialize
                @response['results'][0]['events'] = @events
                @response['truncated'] = @truncated.to_s  if @truncated
                @response.to_json
            end


            private
            def format_msg
                @msg.strip!
                @msg << '.' if @msg.length > 0 && @msg[-1] != '.'    # close previous sentence
            end


            private
            def process_failure
                reason = ''
                if @cmd_result.exception
                    ex = @cmd_result.exception
                    if ex.is_a?(ActivityFatalError) && ex.root_exception
                        # if ex has root_exception, use root's info
                        root = ex.root_exception
                        if root.is_a?(ExternalInvocationError)
                            @msg = root.output.dup
                            reason = root.reason.strip
                        else
                            @msg = root.message.dup
                        end
                        @return_code = root.respond_to?(:exit_code) ? root.exit_code : 1
                    else
                        @msg = ex.message.dup
                        @return_code = 1
                    end
                end

                format_msg
                if @msg.length > MAX_OUTPUT_MSG_SIZE
                    @msg = TRUNCATION_TOKEN + @msg[-MAX_OUTPUT_MSG_SIZE .. -1]
                    @truncated = true
                end

                @msg << " \n" << reason if reason.length > 0
                format_msg
            end
        end
    end
end


