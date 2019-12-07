
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spectre'

Gem::Specification.new do |spec|
  spec.name          = 'spectre'
  spec.version       = Spectre::VERSION
  spec.authors       = ['Christian Neubauer']
  spec.email         = ['me@christianneubauer.de']

  spec.summary       = 'A tool and DSL to specify and run different kind of tests'
  spec.description   = 'A tool and DSL to specify and run different kind of tests'
  spec.homepage      = 'https://bitbucket.org/cneubaur/spectre'

  spec.files         += Dir.glob('bin/*')
  spec.files         += Dir.glob('lib/**/*')

  spec.executables   = ['spectre.rb']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-mocks'
  spec.add_development_dependency 'rspec-expectations'
end
