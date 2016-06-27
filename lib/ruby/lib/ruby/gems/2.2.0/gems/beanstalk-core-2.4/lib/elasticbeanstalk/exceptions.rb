
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

require 'executor'

module ElasticBeanstalk
    class BeanstalkRuntimeError < RuntimeError; end

    class ExternalInvocationError < Executor::NonZeroExitStatus
        attr_accessor :reason, :output
        def initialize (reason:, output:, exit_code:)
            super(msg: output, exit_code: exit_code)
            @reason = reason
            @output = output
        end
    end

    class ActivityFatalError < RuntimeError;
        # msg is the exception root cause
        attr_accessor :activity_path, :activity_error_msg, :root_exception

        def initialize (msg:, activity_path: '', root_exception: nil)
            super(msg)
            @activity_error_msg = msg
            @activity_path = activity_path
            @root_exception = root_exception
        end

        def activity_path_message
            activity_prefix << message
        end

        def activity_prefix
            "[#{@activity_path}] "
        end
    end

    class ActivityTimeoutError < ActivityFatalError; end
    class ActivityInternalError < ActivityFatalError; end

    # Dump error message and stack trace from exception
    # full_trace: when set to false only root cause exception trace is dumped, otherwise trace of every
    #     nested exception is dumped. For debug use.

    def self.format_exception(e, full_trace: true)
        message = ""
        top_exception = true

        while e
            if top_exception
                top_exception = false
            else
                message << %[caused by: ]
            end

            message << %[#{e.message.gsub(/\n/, "\n  ")} (#{e.class})\n]
            if back_trace_exception?(e)
                first_trace = e.backtrace.first
                message << %[\tat #{first_trace}\n]

                if full_trace
                    depth = e.backtrace.length - 1
                else
                    depth = 0
                end

                e.backtrace[1 .. depth].each do |line|
                    message << %[\tfrom #{line}\n]
                end

                message << %[\t...\n] if depth < e.backtrace.length - 1
            end

            e = e.cause
        end

        %[#{message}\n]
    end

    def self.back_trace_exception?(e)
        if e.is_a?(Executor::NonZeroExitStatus) ||
            (e.is_a?(ActivityFatalError) && e.root_exception.is_a?(Executor::NonZeroExitStatus))
            false
        else
            true
        end
    end

end
