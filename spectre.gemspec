require_relative 'lib/spectre'

Gem::Specification.new do |spec|
  spec.name          = "spectre-core"
  spec.version       = Spectre::VERSION
  spec.authors       = ["Christian Neubauer"]
  spec.email         = ["me@christianneubauer.de"]

  spec.summary       = "Describe and run automated tests"
  spec.description   = "A DSL and command line tool to describe and run automated tests"
  spec.homepage      = "https://bitbucket.org/cneubaur/spectre-core"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://bitbucket.org/cneubaur/spectre-core"
  spec.metadata["changelog_uri"] = "https://bitbucket.org/cneubaur/spectre-core/src/master/CHANGELOG.md"

  spec.files        += Dir.glob('lib/**/*')
  spec.files        += Dir.glob('exe/*')

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'ectoplasm', '>= 1.2.0'
  spec.add_runtime_dependency 'openssl', '~> 2.2.0'
  spec.add_runtime_dependency 'net-ssh', '~> 6.1.0'
  spec.add_runtime_dependency 'net-sftp', '~> 3.0.0'
  spec.add_runtime_dependency 'mysql2', '~> 0.5.3'
end
