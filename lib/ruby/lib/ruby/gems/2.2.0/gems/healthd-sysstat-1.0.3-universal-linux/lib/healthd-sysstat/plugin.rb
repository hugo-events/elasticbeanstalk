require 'healthd/daemon/plugins/fixed_interval_base'
require 'healthd/daemon/logger'
require 'executor'

module Healthd
    module Plugins
        module Sysstat
            class Plugin < Daemon::Plugins::FixedIntervalBase
                namespace 'system'

                include Executor

                @@loadavg_path = '/proc/loadavg'
                @@stat_path = '/proc/stat'
                @@meminfo_path = '/proc/meminfo'
                @@cpuinfo_path = '/proc/cpuinfo'
                @@diskspace_refresh_after = 300
                @@cpuinfo_regexp = /^processor\s*:/
                @@meminfo_regexp = /([\w\(\)]+):\s+([0-9]+)/
                @@meminfo_keys = {
                    'MemTotal'     => 'mem_total',
                    'MemAvailable' => 'mem_available',
                    'MemFree'      => 'mem_free',
                    'Buffers'      => 'buffers',
                    'Cached'       => 'cached',
                    'SwapCached'   => 'swap_cached',
                    'SwapTotal'    => 'swap_total',
                    'SwapFree'     => 'swap_free'
                }
                @@pid_name_regexp = /.*\/(.*)\.pid$/

                def setup
                    # initialize cpu_usage
                    cpu_usage
                end

                def snapshot
                    data = {}
                    data = loadavg data
                    data = cpu_usage data
                    data = disk_space data
                    data = meminfo data
                    data = processor_count data
                    data = pids data
                    data
                end

                private
                def loadavg(data={})
                    h = {}
                    h['1'], 
                    h['5'], 
                    h['15'] = File.read(@@loadavg_path).split.first(3).collect { |i| i.to_f.round 2 }

                    data['loadavg'] = h
                    data
                end

                private
                def cpu_usage(data={})
                    h = {}
                    h['user'], 
                    h['nice'], 
                    h['system'], 
                    h['idle'], 
                    h['iowait'], 
                    h['irq'], 
                    h['softirq'] = File.read(@@stat_path).each_line.first.split.drop(1).collect(&:to_i)

                    delta = h.merge @cpu_usage do |key, current, previous|
                        current - previous
                    end if @cpu_usage
                    @cpu_usage = h

                    data['cpu_usage'] = delta
                    data
                end

                private
                def disk_space(data={})
                    @diskspace_at ||= Time.at 0
                    @diskspace ||= nil

                    if Time.now - @diskspace_at > @@diskspace_refresh_after
                        if stats = fs_stats
                            @diskspace_at = Time.now
                            @diskspace = stats
                        end
                    end

                    raise "diskspace statistics not available" unless @diskspace

                    data['disk_space'] = { '/' => @diskspace }
                    data
                end

                private
                def fs_stats
                    output = sh %[stat --file-system --format "%s %b %a" /]
                    h = {}
                    h['block_size'],
                    h['block_count'],
                    h['free_blocks'] = output.split.collect(&:to_i)

                    if h.values.count(&:itself) != 3
                        Daemon::Logger.warn "invalid filesystem statistics. output: #{output}"
                        nil
                    else
                        h
                    end
                rescue Executor::NonZeroExitStatus => e
                    Daemon::Logger.warn "could not fetch filesystem statistics. exit status: #{e.exit_code}, message: #{e.message}"
                    nil
                end

                private
                def meminfo(data={})
                    raw = File.read(@@meminfo_path)
                    h = raw.each_line.first(20).inject({}) do |h, line|
                        _, key, value = line.match(@@meminfo_regexp).to_a
                        value = value.to_i

                        h[@@meminfo_keys[key]] = value if @@meminfo_keys.include? key
                        h
                    end

                    data['meminfo'] = h
                    data
                end

                private
                def processor_count(data={})
                    @processor_count ||= begin
                        cpuinfo = File.read(@@cpuinfo_path) rescue nil
                        count = cpuinfo.scan(@@cpuinfo_regexp).count
                        count if count > 0
                    end

                    data['processor_count'] = @processor_count if @processor_count
                    data
                end

                private
                def pids(data={})
                    @pid_name_cache ||= {}

                    h = Dir.glob("#{options.beanstalk_base_path}/*.pid").inject({}) do |h, path|
                        name = @pid_name_cache[path]

                        unless name
                            name = path[@@pid_name_regexp, 1]
                            @pid_name_cache[path] = name
                        end

                        h[name] = running? path
                        h
                    end

                    data['service_status'] = h
                    data
                end

                private
                def running?(path)
                    pid = if File.exists? path
                        contents = File.read(path)
                        return false if contents.empty?
                        contents.to_i
                    end

                    case
                    when pid && ( Process.getpgid pid rescue nil )
                        true
                    when pid
                        false
                    else
                        nil
                    end
                end
            end
        end
    end
end
