# -*- encoding: utf-8 -*-
# stub: beanstalk-core-healthd 1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "beanstalk-core-healthd"
  s.version = "1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Amazon Web Services"]
  s.date = "2015-09-15"
  s.description = "Internal utilities for AWS Elastic Beanstalk healthd integration on the instance"
  s.executables = ["healthd-restart", "healthd-configure", "healthd-proxy-log-cleanup", "healthd-track-pidfile"]
  s.files = ["bin/healthd-configure", "bin/healthd-proxy-log-cleanup", "bin/healthd-restart", "bin/healthd-track-pidfile"]
  s.homepage = "https://aws.amazon.com/elasticbeanstalk/"
  s.licenses = ["AWS Customer Agreement (http://aws.amazon.com/agreement/)"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1")
  s.rubygems_version = "2.4.5.1"
  s.summary = "AWS Elastic Beanstalk healthd utilities"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version
end
