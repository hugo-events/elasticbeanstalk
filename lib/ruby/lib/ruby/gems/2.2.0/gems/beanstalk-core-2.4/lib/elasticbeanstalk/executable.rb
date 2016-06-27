
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
require 'pathname'

module ElasticBeanstalk
    class Executable
        attr_reader :path

        def self.create(path, eb_executable: false)
            eb_ruby_script = eb_ruby_script?(path)
            if eb_executable || eb_ruby_script
                BeanstalkExecutable.new(path, eb_ruby_script)
            else
                UserExecutable.new(path)
            end
        end

        def self.executable?(file_path)
            file_name = File.basename(file_path)
            is_hidden = /^([\.].*|.+\.bak|.+\.tmp)$/ =~ file_name

            is_executable = File.executable?(file_path)

            !File.directory?(file_path) && is_executable && !is_hidden
        end

        private
        def initialize(path)
            @path = path
        end

        private
        def self.eb_ruby_script?(path)
            file_ext = Pathname(path).extname
            first_line = File.open(path) { |f| f.first }
            file_ext == '.rb' && first_line.chop == "# Beanstalk"
        end
    end

    class BeanstalkExecutable < Executable
        include Executor

        def execute!
            if @eb_ruby_script
                File.open(@path, 'r') do |file|
                    self.instance_eval(file.read, file.path, 1)
                end
            else
                sh(@path, print_cmd_on_error: false, env: ENV)
            end
        end

        private
        def initialize(path, eb_ruby_script)
            super(path)
            @eb_ruby_script = eb_ruby_script
        end
    end

    class UserExecutable < Executable
        include Executor
        def execute!
            sh(@path, print_cmd_on_error: false)
        end
    end
end

