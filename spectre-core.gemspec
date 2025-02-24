# frozen_string_literal: true

require_relative 'lib/spectre/version'

Gem::Specification.new do |spec|
  spec.name          = 'spectre-core'
  spec.version       = Spectre::VERSION
  spec.authors       = ['Christian Neubauer']
  spec.email         = ['christian.neubauer@ionos.com']

  spec.summary       = 'Describe and run automated tests'
  spec.description   = 'A DSL and command line tool to describe and run automated tests'
  spec.homepage      = 'https://github.com/ionos-spectre/spectre-core'
  spec.license       = 'GPL-3.0-or-later'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['source_code_uri']   = 'https://github.com/ionos-spectre/spectre-core'
  spec.metadata['changelog_uri']     = 'https://github.com/ionos-spectre/spectre-core/blob/master/CHANGELOG.md'
  spec.metadata['allowed_push_host'] = 'https://rubygems.pkg.github.com/ionos-spectre'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']
  spec.bindir = 'exe'
  spec.executables = 'spectre'

  spec.add_dependency 'debug', '~> 1.0'
  spec.add_dependency 'ectoplasm', '~> 1.4'
  spec.add_dependency 'logger', '~> 1.0'
  spec.add_dependency 'ostruct', '~> 0.1'
  spec.add_dependency 'stringio', '~> 3.0'
end
