# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'configuru/version'

Gem::Specification.new do |spec|
  spec.name          = 'configuru'
  spec.version       = Configuru::VERSION
  spec.authors       = ['moonfly (Andrey Pronin)']
  spec.email         = ['moonfly.msk@gmail.com']
  spec.summary       = 'Configuration for your classes'
  spec.description   = 'Provides convenient interface for managing configuration parameters for modules, classes and instances.'
  spec.homepage      = 'https://github.com/moonfly/configuru'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.rdoc_options = ['--charset=UTF-8']
  spec.extra_rdoc_files = %w(README.md CONTRIBUTORS.md LICENSE.md)

  spec.required_ruby_version = '>= 2.1.0'

  spec.add_development_dependency 'bundler', '>= 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'coveralls'
end
