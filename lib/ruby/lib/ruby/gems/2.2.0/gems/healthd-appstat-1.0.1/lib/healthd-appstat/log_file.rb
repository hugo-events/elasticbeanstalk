module Healthd
    module Plugins
        module Appstat
            class LogFile
                @@poll_interval = 0.25
                @@rotation_counter = 10
                @@max_file_scan_window = 1024 * 1024   # 1 MB

                def self.open(path, mode:, &block)
                    unless File.exists? %[#{path}.#{timestamp}]
                        raise Exceptions::PluginRuntimeError, %[log file "#{path}.#{timestamp}" does not exist]
                        skip
                    end

                    case mode
                    when 'follow'
                        follow path, &block
                    when 'batch'
                        batch path, &block
                    else
                        raise %[invalid mode: "#{mode}"]
                    end
                end

                private
                def self.batch(path)
                    file = reopen :path => path, :skip => false

                    begin
                        yield file
                    ensure
                        file.close
                    end
                end

                private
                def self.follow(path, interval: @@poll_interval)
                    rotation_counter = @@rotation_counter

                    proc = Proc.new
                    file = reopen :path => path

                    begin
                        loop do
                            lines_cut = proc.call file

                            if lines_cut
                                rotation_counter = @@rotation_counter
                            else
                                rotation_counter -= 1
                                if rotation_counter == 0
                                    rotation_counter = @@rotation_counter
                                    file = reopen :file => file, :path => path
                                end
                            end

                            sleep interval
                        end
                    ensure
                        file.close unless file.closed?
                    end
                end

                private
                def self.reopen(file: nil, path:, skip: true)
                    current_file_path = %[#{path}.#{timestamp}]

                    if !file || file.path != current_file_path || ! (file.lstat rescue nil)
                        file.close if file && !file.closed?
                        file = File.open current_file_path, 'r'

                        # only scan at most 1 MB - resending data is harmless
                        if skip && file.size > @@max_file_scan_window
                            file.pos = file.size - @@max_file_scan_window

                            # discard the first possibly partial line
                            file.gets

                            # required so that the C extension starts from the correct position
                            file.pos
                        end
                    end
                    file
                rescue Errno::ENOENT
                    raise Exceptions::PluginRuntimeError, %[log file "#{path}.#{timestamp}" does not exist]
                end

                private
                def self.timestamp
                    Time.now.utc.strftime "%Y-%m-%d-%H".freeze
                end
            end
        end
    end
end
