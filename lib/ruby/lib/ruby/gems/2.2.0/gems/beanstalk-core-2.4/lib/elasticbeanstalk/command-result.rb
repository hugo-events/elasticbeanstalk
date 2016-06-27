
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

require 'elasticbeanstalk/event'

module ElasticBeanstalk
    class CommandResult
        SUCCESS = 'SUCCESS'
        FAILURE = 'FAILURE'

        attr_accessor :status, :msg, :events, :config_sets, :return_code, :exception, :ignored
        
        def initialize(status: FAILURE, msg: '', events: [], config_sets: '', return_code: 0, exception: nil, ignored: false)
            @status = status
            @msg = msg
            @events = events
            @config_sets = config_sets
            @return_code = return_code
            @exception = exception
            @ignored = ignored
        end
        
        def process_events(events_file)
            @events = YAML.load_documents(File.read(events_file)).collect do |e|
                if e && e['msg'] && ! e['msg'].strip.empty?
                    event = Event.new(msg: e['msg'],
                                      severity: e.fetch('severity', :INFO),
                                      timestamp: e.fetch('timestamp', Time.now.to_ms))
                end
                event
            end
            @events.compact!
        end
    end
end
