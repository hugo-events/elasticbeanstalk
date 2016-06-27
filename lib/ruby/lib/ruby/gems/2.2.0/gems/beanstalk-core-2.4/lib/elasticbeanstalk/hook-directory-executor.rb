
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

require 'pathname'

require 'executor'
require 'elasticbeanstalk/activity'
require 'elasticbeanstalk/executable'

module ElasticBeanstalk
    class HookDirectoryExecutor

        def run!(path)
            executables(path).each do |executable|
                filename = Pathname.new(executable.path).basename
                Activity.create(name: filename) do
                    begin
                        executable.execute!
                    rescue Executor::NonZeroExitStatus => e
                        raise ExternalInvocationError.new(
                                  reason: "Hook #{File.join(path, filename)} failed.",
                                  output: e.message,
                                  exit_code: e.exit_code
                              )
                    end
                end
            end
            "Successfully execute hooks in directory #{path}."
        end

        def executables(path)
            files = Dir.glob("#{path}/*").select {|file_path| Executable.executable?(file_path)}
            files.sort.collect { |file_path| Executable.create(file_path) }
        end
    end
end
