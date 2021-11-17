# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'rack/remote/version'

Gem::Specification.new do |spec|
  spec.name          = 'rack-remote'
  spec.version       = Rack::Remote::VERSION
  spec.authors       = ['Jan Graichen']
  spec.email         = %w[jg@altimos.de]
  spec.summary       = 'Small request intercepting rack middleware to ' \
                       'invoke remote calls over HTTP.'
  spec.description   = 'Small request intercepting rack middleware to ' \
                       'invoke remote calls over HTTP.'
  spec.homepage      = 'https://github.com/jgraichen/rack-remote'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) {|f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w[lib]

  spec.add_dependency 'multi_json'
  spec.add_dependency 'rack'

  spec.add_development_dependency 'bundler'
end
