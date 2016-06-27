
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

require 'fileutils'
require 'time'

class Time
    def to_ms
        (self.to_f * 1000).to_i
    end
end


module ElasticBeanstalk

    module Utils

        @@eb_user_group = 'awseb'

        def self.logger_formatter
            proc do |severity, datetime, progname, msg|
                @@pid ||= "[#{Process.pid}]"
                log_msg = "[#{datetime.utc.iso8601(3)}] #{severity.ljust(5)} #{@@pid.ljust(7)}"
                if progname.nil? || progname.empty?
                    log_msg = log_msg + " : #{msg}\n"
                else
                    log_msg = log_msg + " - [#{progname}] : #{msg}\n"
                end
                log_msg
            end
        end


        # extract substring using regex
        # return nil if no match found
        def self.extract_string(string:, regex:, index: 1, strip: true)
            result = self.extract_strings(string: string, regex: regex, indices: [index], strip: strip)
            if result.empty?
                nil
            else
                result[0]
            end
        end

        # extract sub strings using regex
        # return [] if no match found
        def self.extract_strings(string:, regex:, indices: [1], strip: true)
            result = []
            if string && ! string.empty?
                m = string.match(regex)
                if m
                    indices.each do |index|
                        text = m[index]
                        text = text.strip if text && strip
                        result << text
                    end
                end
            end
            result
        end

        def self.set_eb_datafile_permission(path)
            FileUtils.chmod(0660, path)
            FileUtils.chown(nil, @@eb_user_group, path)
        end

        def self.random_backoff(attempt, max_delay: 300)
            [Random.rand(2 ** attempt / 1.0), max_delay + Random.rand(10.0)].min
        end
    end
end
