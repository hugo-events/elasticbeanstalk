# -*- encoding: utf-8 -*-
# stub: docopt 0.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "docopt"
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Blake Williams", "Vladimir Keleshev", "Alex Speller", "Nima Johari"]
  s.date = "2012-09-01"
  s.description = "Isn't it awesome how `optparse` and other option parsers generate help and usage-messages based on your code?! Hell no!\nYou know what's awesome? It's when the option parser *is* generated based on the help and usage-message that you write in a docstring! That's what docopt does!"
  s.email = "code@shabbyrobe.org"
  s.extra_rdoc_files = ["README.md", "LICENSE"]
  s.files = ["LICENSE", "README.md"]
  s.homepage = "http://github.com/docopt/docopt.rb"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--charset=UTF-8"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.rubygems_version = "2.4.5.1"
  s.summary = "A command line option parser, that will make you smile."

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 2

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<json>, ["~> 1.6.5"])
    else
      s.add_dependency(%q<json>, ["~> 1.6.5"])
    end
  else
    s.add_dependency(%q<json>, ["~> 1.6.5"])
  end
end
