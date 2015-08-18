# coding: utf-8
lib = File.expand_path('../src', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vbms/version'

Gem::Specification.new do |spec|
  spec.name          = "connect_vbms"
  spec.version       = VBMS::VERSION
  spec.authors       = ["Alex Gaynor", "Bill Mill", "Albert Wong"]
  spec.email         = ["alex.gaynor@va.gov", "bill@adhocteam.us", "albert.wong@va.gov"]

  spec.platform      = Gem::Platform::RUBY
  spec.summary       = %q{Connect to VBMS with ease}
  spec.description   = %q{Connect to VBMS with ease}
  spec.homepage      = "http://va.gov"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = ""
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  git_files          = `git ls-files -z`.split("\x00").reject { |f| f.match(%r{^(test|spec|features|\.java)/}) }
  spec.files         = git_files + Dir['classes/*.class']
  spec.require_paths = ["src"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.3"
  spec.add_development_dependency "equivalent-xml", "~> 0.6"
  spec.add_development_dependency "simplecov", "~> 0.10"

  spec.add_runtime_dependency "httpi", "~> 2.4"
  spec.add_runtime_dependency "nokogiri", "~> 1.6"
  spec.add_runtime_dependency "xmlenc", "~> 0.2"
end
