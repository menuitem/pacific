# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pacific/version'

Gem::Specification.new do |spec|
  spec.name          = "pacific"
  spec.version       = Pacific::VERSION
  spec.authors       = ["Lucjan Stepien"]
  spec.email         = ["lucjan.stepien@ncirl.student.ie"]
  spec.summary       = %q{Rails fancy deployment.}
  spec.description   = %q{Gem for deploying Rails 3 and Rails 4 applications to Linux based infrastructures.}
  spec.homepage      = "https://github.com/menuitem/pacific"
  spec.license       = "MIT"
  spec.executables   = ["pacific"] 
  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib", "pacific"]
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 0"
  spec.add_dependency "net-ssh", "~> 2.9.1"
  spec.add_dependency "net-scp", "~> 1.2.1"
end
  # spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
