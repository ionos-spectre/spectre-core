require 'ostruct'

require_relative './spectre/core'
require_relative './spectre/runner'

module Spectre
  module Version
    MAJOR = 2
    MINOR = 0
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'

  def self.load config_file, env_name
    config_loader = Spectre::ConfigLoader.new
    config = config_loader.load(config_file)

    environment = Spectre::Environment.new
    environment.load(config['env_patterns'], config['env_partial_patterns'], config['working_dir'], config)
    env_config = environment.get(env_name)

    config.deep_merge! env_config

    config
  end

  def self.setup config
    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)

    spectre_scope.configure(config)

    spectre_scope.load_specs(config['spec_patterns'], config['working_dir'])
    spectre_scope.load_modules(config['modules'], config)

    spectre_scope
  end

  def self.run spectre_scope, specs
    Spectre::Runner.new(spectre_scope).run(specs)
  end
end
