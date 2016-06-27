# -*- encoding: utf-8 -*-
# stub: beanstalk-core 2.4 ruby lib

Gem::Specification.new do |s|
  s.name = "beanstalk-core"
  s.version = "2.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Amazon Web Services Elastic Beanstalk"]
  s.date = "2016-05-26"
  s.description = "Common utilities for AWS Elastic Beanstalk on-instance use"
  s.email = "nospam@amazon.com"
  s.executables = ["command-processor", "download_source_bundle", "get-config", "log-conf"]
  s.files = ["bin/command-processor", "bin/download_source_bundle", "bin/get-config", "bin/log-conf"]
  s.homepage = "https://aws.amazon.com/elasticbeanstalk/"
  s.licenses = ["Amazon Software License"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1")
  s.rubygems_version = "2.4.5.1"
  s.summary = "AWS EB core utilities"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<executor>, ["~> 1.1"])
    else
      s.add_dependency(%q<executor>, ["~> 1.1"])
    end
  else
    s.add_dependency(%q<executor>, ["~> 1.1"])
  end
end
