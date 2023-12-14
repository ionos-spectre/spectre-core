require 'ostruct'

require_relative './spectre/core'
require_relative './spectre/runner'
require_relative './spectre/reporter'

module Spectre
  module Version
    MAJOR = 2
    MINOR = 0
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'

  def self.load config_file, env_name=nil
    config_loader = Spectre::ConfigLoader.new
    config = config_loader.load(config_file)

    environment = Spectre::Environment.new
    environment.load(config['env_patterns'], config['env_partial_patterns'], config['working_dir'])
    env_config = environment.get(env_name)

    config.deep_merge! env_config

    config
  end

  def self.setup config
    # Load bootstrap file if exists
    bootstrap_file = File.join(config['working_dir'], config['bootstrap_file'])
    require_relative bootstrap_file if File.exist? bootstrap_file

    # Load modules
    config['modules']
      .reject { |mod| config['exclude'].include? mod }
      .concat(config['include'])
      .each do |mod|
        require mod
      end

    Spectre::SpectreScope.new
      .configure(config)
      .load_specs(config['spec_patterns'], config['working_dir'])
  end

  def self.run spectre_scope, specs
    Spectre::Runner.new(spectre_scope).run(specs)
  end

  def self.define(name, &)
    Spectre::SpectreScope.define(name, &)
  end

  def self.report run_infos, config, reporters=nil
    Spectre::Reporter.report(run_infos, config, reporters)
  end
end
