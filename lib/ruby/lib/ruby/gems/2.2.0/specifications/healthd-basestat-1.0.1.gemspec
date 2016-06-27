# -*- encoding: utf-8 -*-
# stub: healthd-basestat 1.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "healthd-basestat"
  s.version = "1.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.metadata = { "healthd-plugin-version" => "1" } if s.respond_to? :metadata=
  s.require_paths = ["lib"]
  s.authors = ["Amazon Web Services"]
  s.date = "2016-05-03"
  s.description = "Beanstalk Base Container status plugin for Health"
  s.homepage = "http://aws.amazon.com/elasticbeanstalk/"
  s.licenses = ["AWS Customer Agreement (http://aws.amazon.com/agreement/)"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1")
  s.rubygems_version = "2.4.5.1"
  s.summary = "Beanstalk Health Base Container Plugin"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<healthd>, [">= 0"])
    else
      s.add_dependency(%q<healthd>, [">= 0"])
    end
  else
    s.add_dependency(%q<healthd>, [">= 0"])
  end
end
