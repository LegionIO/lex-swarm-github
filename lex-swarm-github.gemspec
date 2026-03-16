# frozen_string_literal: true

require_relative 'lib/legion/extensions/swarm_github/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-swarm-github'
  spec.version       = Legion::Extensions::SwarmGithub::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Swarm GitHub'
  spec.description   = 'GitHub-specific swarm pipeline (finder/fixer/validator) for brain-modeled agentic AI'
  spec.homepage      = 'https://github.com/LegionIO/lex-swarm-github'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-swarm-github'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-swarm-github'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-swarm-github'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-swarm-github/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,spec}/**/*') + %w[lex-swarm-github.gemspec Gemfile]
  end
  spec.require_paths = ['lib']
  spec.add_development_dependency 'legion-gaia'
end
