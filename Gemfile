# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in rack-remote.gemspec
gemspec

# Development gems
#
gem 'rake'
gem 'rspec', '~> 3.0'

group :development do
  gem 'rubocop-config', github: 'jgraichen/rubocop-config', tag: 'v14', require: false
end

group :test do
  gem 'rspec-github', require: false
  gem 'rspec-rails'

  gem 'simplecov'
  gem 'simplecov-cobertura'

  gem 'rack-test'
  gem 'webmock', '~> 3.0'
end
