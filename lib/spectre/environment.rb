require 'date'

require_relative 'config'

module Spectre
  attr_reader :envs

  class Environment
    @@default_env_name = 'default'

    @envs = {}

    def get name=nil
      @envs[name || @@default_env_name] || {}
    end

    def load env_patterns, env_partial_patterns, working_dir, config
      @envs = {}

      read_env_files = {}

      env_patterns.each do |pattern|
        pattern = File.join(working_dir, pattern)

        Dir.glob(pattern).each do |env_file|
          spec_env = ConfigLoader.load_yaml(env_file)

          name = spec_env['name'] || @@default_env_name

          if @envs.key? name
            existing_env_file = read_env_files[name]
            puts "Duplicate environment definition detected with name #{name} in '#{env_file}'. Previously defined in '#{existing_env_file}'"
            exit 1
          end

          read_env_files[name] = env_file

          @envs[name] = config
            .deep_clone
            .deep_merge(spec_env)
        end
      end

      # Merge partial environment configs with existing environments
      env_partial_patterns.each do |pattern|
        pattern = File.join(working_dir, pattern)

        Dir.glob(pattern).each do|env_file|
          partial_env = ConfigLoader.load_yaml(env_file)
          name = partial_env.delete('name') || @@default_env_name

          next unless @envs.key? name

          @envs[name].deep_merge!(partial_env)
        end
      end

      self
    end
  end
end
