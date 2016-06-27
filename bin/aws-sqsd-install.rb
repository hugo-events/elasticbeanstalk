#!/usr/bin/env ruby

require 'aws-sdk'
require 'fileutils'
require 'open-uri'

BUCKET = 'elasticbeanstalk-env-resources-eu-west-1'
GEM_NAME = 'aws-sqsd-2.3.gem'
GEM_KEY = "eb_sqsd/#{GEM_NAME}"
GEM_PATH = "/var/tmp/#{GEM_NAME}"
USER = "sqsd"
GROUP = 'awseb'
S3_URL_BASE="s3-eu-west-1.amazonaws.com"
# download the gem
uri = %[https://#{BUCKET}.#{S3_URL_BASE}/#{GEM_KEY}]
open(uri) do |s|
    open(GEM_PATH, "w") do |f|
        while buf = s.read(32768)
            f.write buf
        end
    end
end

# install the gem
system %[gem install --local --bindir /opt/elasticbeanstalk/lib/ruby/bin #{GEM_PATH} 2>&1]
unless $?.exitstatus == 0
    puts %[installing gem "#{GEM_PATH}" failed]
    exit 1
end
FileUtils.rm_f GEM_PATH

# create the daemon user
unless (Etc.getpwnam USER rescue nil)
    system %[/usr/sbin/groupadd -f -r #{GROUP}]
    unless $?.exitstatus == 0
        puts %[creating the group "#{GROUP}" failed]
        exit 1
    end

    system %[/usr/sbin/useradd -g #{GROUP} --no-create-home --comment "AWS SQSD Daemon" #{USER}]
    unless $?.exitstatus == 0
        puts %[creating the user "#{USER}" failed]
        exit 1
    end
end

# create log pid and configuration directories
%w[/var/log/aws-sqsd /var/run/aws-sqsd /etc/aws-sqsd.d].each do |path|
    FileUtils.mkdir_p path
    FileUtils.chown USER, GROUP, path
end
