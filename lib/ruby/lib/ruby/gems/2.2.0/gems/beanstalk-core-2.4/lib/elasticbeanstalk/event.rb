
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

require 'elasticbeanstalk/cfn-wrapper'
require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/utils'

module ElasticBeanstalk

    class Event
        include Comparable

        @@severity_map = {:SYSTEM => 0, :TRACE => 1, :DEBUG => 2, :INFO => 3, :WARN=> 4, :ERROR => 5, :FATAL => 6}
        
        def self.severity_map
            @@severity_map
        end

        attr_accessor :msg, :severity, :timestamp

        def initialize(msg:, severity: :INFO, timestamp: Time.now.to_ms)
            @msg = msg.strip
            severity_sym = severity.upcase.to_sym
            if @@severity_map.has_key?(severity_sym)
                @severity = severity_sym
            else
                raise BeanstalkRuntimeError, %[Cannot parse event severity '#{severity}'.]
            end
            @timestamp = timestamp ? timestamp : Time.now.to_ms
        end

        def <=> other
            [@@severity_map[@severity], @timestamp] <=> [@@severity_map[other.severity], other.timestamp]
        end

        def to_hash
            {
                "msg" => @msg,
                "severity" => @severity,
                "timestamp" => @timestamp
            }
        end

        def to_json(options = {})
            to_hash.to_json(options)
        end

        def upload(env_metadata:)
            report = {
                'time' => Time.now.to_ms,
                'type' => 'CmdEvent',
                'data' => to_hash,
            }
            CfnWrapper.send_cmd_event(payload: JSON.generate(report), env_metadata: env_metadata)
        end

    end

end
