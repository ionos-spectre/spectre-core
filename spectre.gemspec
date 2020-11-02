
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spectre'

Gem::Specification.new do |spec|
  spec.name          = 'spectre'
  spec.version       = Spectre::VERSION
  spec.authors       = ['Christian Neubauer']
  spec.email         = ['me@christianneubauer.de']

  spec.summary       = 'A DSL and command line tool to describe and run automated tests'
  spec.description   = 'A DSL and command line tool to describe and run automated tests'
  spec.homepage      = 'https://bitbucket.org/cneubaur/spectre-ruby'
  spec.license       = 'MIT'

  spec.files         += Dir.glob('bin/*')
  spec.files         += Dir.glob('lib/**/*')

  spec.executables   = ['spectre', 'spectre.bat']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-mocks'
  spec.add_development_dependency 'rspec-expectations'
end
