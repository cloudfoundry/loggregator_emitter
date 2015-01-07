# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "loggregator_emitter"
  spec.version       = '3.0.0'
  spec.authors       = ["Pivotal"]
  spec.email         = ["cf-eng@pivotallabs.com"]
  spec.description   = "Library to emit data to Loggregator"
  spec.summary       = "Library to emit data to Loggregator"
  spec.homepage      = "https://www.github.com/cloudfoundry/loggregator_emitter"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(spec)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  spec.add_dependency "beefcake", "~> 1.0.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.1.0"
  spec.add_development_dependency "rspec", "~> 2.14.1"
  spec.add_development_dependency "coveralls"
end
