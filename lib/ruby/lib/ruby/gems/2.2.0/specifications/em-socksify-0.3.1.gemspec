# -*- encoding: utf-8 -*-
# stub: em-socksify 0.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = "em-socksify"
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Ilya Grigorik"]
  s.date = "2015-09-21"
  s.description = "Transparent proxy support for any EventMachine protocol"
  s.email = ["ilya@igvita.com"]
  s.homepage = "https://github.com/igrigorik/em-socksify"
  s.licenses = ["MIT"]
  s.rubyforge_project = "em-socksify"
  s.rubygems_version = "2.4.5.1"
  s.summary = "Transparent proxy support for any EventMachine protocol"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<eventmachine>, [">= 1.0.0.beta.4"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<eventmachine>, [">= 1.0.0.beta.4"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<eventmachine>, [">= 1.0.0.beta.4"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
