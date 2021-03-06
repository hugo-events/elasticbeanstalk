# -*- encoding: utf-8 -*-
# stub: chainsaw 1.0.1 ruby lib ext
# stub: ext/chainsaw/extconf.rb

Gem::Specification.new do |s|
  s.name = "chainsaw"
  s.version = "1.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib", "ext"]
  s.authors = ["Amazon Web Services"]
  s.date = "2016-05-03"
  s.description = "String processing library with enhanced String#split like interface"
  s.extensions = ["ext/chainsaw/extconf.rb"]
  s.files = ["ext/chainsaw/extconf.rb"]
  s.homepage = "http://aws.amazon.com/elasticbeanstalk/"
  s.licenses = ["AWS Customer Agreement (http://aws.amazon.com/agreement/)"]
  s.rubygems_version = "2.4.5.1"
  s.summary = "String#split with transformations"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>, ["~> 1.6"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rake-compiler>, [">= 0"])
    else
      s.add_dependency(%q<bundler>, ["~> 1.6"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rake-compiler>, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>, ["~> 1.6"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rake-compiler>, [">= 0"])
  end
end
