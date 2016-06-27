
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

require 'elasticbeanstalk/exceptions'
require 'elasticbeanstalk/utils'

module ElasticBeanstalk

    class CommandRequest

        # infra attributes
        attr_reader :cfn_command_name, :invocation_id, :dispatcher_id

        # common attributes
        attr_accessor :api_version
        attr_accessor :command_name, :request_id
        attr_accessor :stage_name, :stage_num
        attr_accessor :instance_ids, :data, :execution_data
        attr_accessor :resource_name, :config_set

        def self.from_env(logger: Logger.new(File.open(File::NULL, 'w')), error_on_not_found: true)
            cmd_data_str = ENV['CMD_DATA']

            unless cmd_data_str
                if error_on_not_found
                    raise BeanstalkRuntimeError.new(%[CMD_DATA not provided!])
                else
                    return nil
                end
            end

            cmd_req = CommandRequest.new(cmd_data_str: cmd_data_str,
                                         logger: logger,
                                         cfn_command_name: ENV['CMD_NAME'],
                                         invocation_id: ENV['INVOCATION_ID'],
                                         dispatcher_id: ENV['DISPATCHER_ID'])
            cmd_req
        end

        def initialize(cmd_data_str:, logger:, cfn_command_name: nil, invocation_id: nil, dispatcher_id: nil)
            @logger = logger
            cmd_data_str = HttpUtils.download(source_uri: cmd_data_str) if cmd_data_str.start_with?('http')
            
            @raw_cmd = cmd_data_str
            @cfn_command_name = cfn_command_name
            @invocation_id = invocation_id
            @dispatcher_id = dispatcher_id

            @cmd_data = JSON.parse(cmd_data_str)
            @api_version = @cmd_data.fetch('api_version', '1.0') # default to be v1.0

            begin
                mod = CommandRequest.const_get("ParserV#{@api_version.to_s.gsub(/\./, '_')}")
                extend mod
            rescue NameError # raised from const_get
                raise BeanstalkRuntimeError, %[Not supported command API version #{@api_version}]
            end

            parse

            raise BeanstalkRuntimeError, %[Missing command name!] unless @command_name
            raise BeanstalkRuntimeError, %[Missing request ID!] unless @request_id
        end

        def last_stage?
            @last_stage
        end

        def to_s
            @raw_cmd.clone
        end

        module ParserV1_0
            def parse
                @command_name = @cmd_data['command_name']
                @request_id = @cmd_data['request_id']
                @config_set = @cmd_data['config_set']
                @stage_name = @cmd_data['stage_name']
                @stage_num = @cmd_data['stage_num']
                @last_stage = @cmd_data['is_last_stage']
                @resource_name = @cmd_data['resource_name']
                @data = @cmd_data['data']
                @execution_data = @cmd_data['execution_data']
                @instance_ids = @cmd_data['instance_ids']
            end
        end
    end
end

