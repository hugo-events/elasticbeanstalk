require 'fileutils'
require 'tempfile'
require 'timeout'

module ElasticBeanstalk
    module Healthd
        @@runtime_dir = '/var/elasticbeanstalk/healthd'
        @@config_file = '/etc/healthd/config.yaml'

        def self.enabled?
            File.exist? @@config_file
        end

        def self.runtime_dir
            @@runtime_dir
        end

        def self.configure_httpd_logging
            raise "Healthd is not enabled" unless enabled?

            FileUtils.mkdir_p "/var/log/httpd/healthd/"
            FileUtils.chmod 0755, "/var/log/httpd/"
            FileUtils.chmod 0755, "/var/log/httpd/healthd/"
            File.open(httpd_conf_location, 'w') do |f|
                f.puts 'LogFormat "%{%s}t\"%U\"%s\"%D\"%D\"%{X-Forwarded-For}i" healthd'
                f.puts 'CustomLog "|/usr/sbin/rotatelogs /var/log/httpd/healthd/application.log.%Y-%m-%d-%H 3600" healthd'
            end

            configure_proxy_log_cleanup :proxy_name => 'httpd'
        end

        def self.configure_nginx_logging
            FileUtils.chmod 0755, "/var/log/nginx/" if File.exist?("/var/log/nginx/")
            FileUtils.chmod 0755, "/var/log/nginx/healthd/" if File.exist?("/var/log/nginx/healthd/")
            configure_proxy_log_cleanup :proxy_name => 'nginx'
        end

        def self.track_pidfile(name:, pidfile:, grace_period: 30)
            raise "Healthd is not enabled" unless enabled?

            create_symlink :source => pidfile,
                           :destination => "#{@@runtime_dir}/#{name}.pid",
                           :grace_period => grace_period
        end

        def self.configure_proxy_log_cleanup(proxy_name:, proxy_log_dir: nil, log_file_name: 'application.log')
            raise "Healthd is not enabled" unless enabled?

            proxy_log_dir ||= "/var/log/#{proxy_name}/healthd"
            # run this executable every hour to delete healthd logs timestamped by hour, standard logrotate does not support hourly log cleanup
            File.open("/etc/cron.hourly/cron.logcleanup.elasticbeanstalk.healthd.#{proxy_name}.conf", "w", 0755) do |f|
                f.puts('#!/bin/sh')
                f.puts(%[find #{proxy_log_dir} -type f | grep -v #{log_file_name}.`date -u +"%Y-%m-%d-%H"` | xargs rm -f])
            end
        end

        def self.configure(appstat_log_path: nil, appstat_unit: nil, appstat_timestamp_on: nil)
            raise "Healthd is not enabled" unless enabled?

            unless appstat_timestamp_on.nil? || appstat_timestamp_on_valid?(appstat_timestamp_on)
                raise "Invalid appstat_timestamp_on: value should be one of completion|arrival"
            end

            tmp_file = Tempfile.new 'healthd'
            tmp_file.chmod 0644

            File.readlines(@@config_file).each do |line|
                case
                when appstat_log_path && line.start_with?('appstat_log_path: ')
                    next
                when appstat_unit && line.start_with?('appstat_unit: ')
                    next
                when appstat_timestamp_on && line.start_with?('appstat_timestamp_on: ')
                    next
                else
                    tmp_file.puts(line)
                end
            end

            tmp_file.puts("appstat_log_path: #{appstat_log_path}") if appstat_log_path && !appstat_log_path.empty?
            tmp_file.puts("appstat_unit: #{appstat_unit}") if appstat_unit && !appstat_unit.empty?
            tmp_file.puts("appstat_timestamp_on: #{appstat_timestamp_on}") if appstat_timestamp_on && !appstat_timestamp_on.empty?

            tmp_file.close

            FileUtils.mv tmp_file.path, @@config_file
        end

        def self.httpd_conf_location
            "/etc/httpd/conf.d/healthd.conf"
        end

        private
        def self.create_symlink(source:, destination:, grace_period: nil)
            # wait for file to exist
            if grace_period
                Timeout::timeout(grace_period) do
                    sleep 1 until File.exist?(source)
                end rescue Timeout::Error
            end

            FileUtils.ln_sf source, destination
        end

        private
        def self.appstat_timestamp_on_valid?(appstat_timestamp_on)
            ['', 'completion', 'arrival'].include? appstat_timestamp_on
        end
    end
end
