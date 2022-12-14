require 'ostruct'

require_relative './spectre/core'

module Spectre
  module Version
    MAJOR = 2
    MINOR = 0
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'

  def self.register name, &block
    SpectreScope.register(name, &block)
  end

  def self.load_modules config
    return unless config.key? 'modules'

    config['modules']
      .concat(config['include'] || [])
      .select { |mod| !(config['exclude'] || []).include? mod }
      .each do |mod|
        begin
          mod_file = mod + '.rb'
          spectre_lib_mod = File.join(File.dirname(__dir__), mod_file)

          if File.exists? mod_file
            require_relative mod_file

          else File.exists? spectre_lib_mod
            require_relative spectre_lib_mod

          end
        rescue LoadError => e
          puts "Unable to load module #{mod}. Check if the module exists or remove it from your spectre config:\n#{e.message}"
          exit 1
        end
      end
  end
end


extend Spectre::Delegator
