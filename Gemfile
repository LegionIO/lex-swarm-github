# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rspec', '~> 3.13'
gem 'rubocop', '~> 1.75', require: false
gem 'rubocop-legion', '~> 0.1'
gem 'rubocop-rspec', require: false

if File.exist?(File.expand_path('../../legion-gaia', __dir__))
  gem 'legion-gaia', path: '../../legion-gaia'
else
  gem 'legion-gaia'
end
