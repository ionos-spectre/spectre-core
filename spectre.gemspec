require_relative 'lib/spectre'

Gem::Specification.new do |spec|
  spec.name          = "spectre"
  spec.version       = Spectre::VERSION
  spec.authors       = ["Christian Neubauer"]
  spec.email         = ["me@christianneubauer.de"]

  spec.summary       = "Describe and run automated tests"
  spec.description   = "A DSL and command line tool to describe and run automated tests"
  spec.homepage      = "https://bitbucket.org/cneubaur/spectre-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://bitbucket.org/cneubaur/spectre-ruby"
  spec.metadata["changelog_uri"] = "https://bitbucket.org/cneubaur/spectre-ruby/src/master/CHANGELOG.md"

  spec.files        += Dir.glob('lib/**/*')
  spec.files        += Dir.glob('exe/*')

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'openssl', '~> 2.2.0'
  spec.add_runtime_dependency 'net-ssh', '~> 6.1.0'
  spec.add_runtime_dependency 'net-sftp', '~> 3.0.0'
end
