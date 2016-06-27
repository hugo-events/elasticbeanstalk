# -*- encoding: utf-8 -*-
# stub: aws-sqsd 2.3 ruby lib

Gem::Specification.new do |s|
  s.name = "aws-sqsd"
  s.version = "2.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Amazon Web Services"]
  s.date = "2016-03-17"
  s.description = "AWS Elastic Beanstalk SQS Daemon. See http://aws.amazon.com/elasticbeanstalk/"
  s.executables = ["aws-sqsd"]
  s.files = ["bin/aws-sqsd"]
  s.homepage = "http://aws.amazon.com/elasticbeanstalk/"
  s.licenses = ["Amazon Software License"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1")
  s.rubygems_version = "2.4.5.1"
  s.summary = "AWS Elastic Beanstalk SQS Daemon"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<aws-sdk>, [">= 2.2.14", "~> 2.2"])
      s.add_runtime_dependency(%q<aws-sdk-core>, [">= 2.2.14", "~> 2.2"])
      s.add_runtime_dependency(%q<executor>, ["~> 1.1"])
      s.add_runtime_dependency(%q<em-http-request>, [">= 1.1.3", "~> 1.1"])
      s.add_runtime_dependency(%q<parse-cron>, [">= 0.1.4", "~> 0.1"])
    else
      s.add_dependency(%q<aws-sdk>, [">= 2.2.14", "~> 2.2"])
      s.add_dependency(%q<aws-sdk-core>, [">= 2.2.14", "~> 2.2"])
      s.add_dependency(%q<executor>, ["~> 1.1"])
      s.add_dependency(%q<em-http-request>, [">= 1.1.3", "~> 1.1"])
      s.add_dependency(%q<parse-cron>, [">= 0.1.4", "~> 0.1"])
    end
  else
    s.add_dependency(%q<aws-sdk>, [">= 2.2.14", "~> 2.2"])
    s.add_dependency(%q<aws-sdk-core>, [">= 2.2.14", "~> 2.2"])
    s.add_dependency(%q<executor>, ["~> 1.1"])
    s.add_dependency(%q<em-http-request>, [">= 1.1.3", "~> 1.1"])
    s.add_dependency(%q<parse-cron>, [">= 0.1.4", "~> 0.1"])
  end
end
