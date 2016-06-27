require 'healthd/daemon/plugins/fixed_interval_base'
require 'oj'

module Healthd
    module Plugins
        module Basestat
            class Plugin < Daemon::Plugins::FixedIntervalBase
                namespace 'base'
                data_expected false

                @@marker_refresh_interval = 3600
                @@commands_key = 'commands'
                @@sqsd_key = 'sqsd'

                def setup
                    @current_path = "#{options.beanstalk_base_path}/current.json"
                    @latest_path = "#{options.beanstalk_base_path}/latest.json"
                    @sqsd_status_path = "#{options.sqsd_base_path}/fault.json"
                end

                def snapshot
                    data = {}

                    if modified?(@current_path) | modified?(@latest_path) | modified?(@sqsd_status_path) | refresh?
                        20.times do |i|
                            data = {}

                            parse_command_file @current_path, :key => 'current', :data => data
                            parse_command_file @latest_path, :key => 'latest', :data => data
                            parse_sqsd_file @sqsd_status_path, :data => data

                            commands = data[@@commands_key]
                            break unless commands && commands['current'] == commands['latest'] && commands['current']
                        end
                    end

                    data
                end

                private
                def parse_command_file(path, key:, data:)
                    document = Oj.load_file path, :mode => :strict
                    if document
                        data[@@commands_key] ||= {}
                        data[@@commands_key][key] = document
                    end

                    data
                end

                private
                def parse_sqsd_file(path, data:)
                    document = Oj.load_file path, :mode => :strict
                    if document
                        data[@@sqsd_key] = document
                    end
                    data
                end

                private
                def modified?(path)
                    @read_at ||= {}
                    mtime = File.mtime path if File.exists? path

                    case
                    when mtime && ( !@read_at[path] || mtime > @read_at[path] )
                        @read_at[path] = mtime
                        true
                    when !mtime && @read_at.delete(path)
                        # reprocess if file was removed
                        true
                    else
                        false
                    end
                end

                private
                def refresh?
                    @refresh_at ||= Time.now + @@marker_refresh_interval

                    if Time.now > @refresh_at
                        @refresh_at = nil
                        true
                    end
                end
            end
        end
    end
end
