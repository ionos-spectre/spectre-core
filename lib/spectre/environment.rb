require 'date'
require 'yaml'

module Spectre
  attr_reader :envs

  class Environment
    @envs = {}

    def get name=nil
      @envs[name || 'default'] || {}
    end

    def load config
      @envs = {}

      read_env_files = {}

      config['env_patterns'].each do |pattern|
        pattern = File.join(config['working_dir'] || Dir.pwd, pattern)

        Dir.glob(pattern).each do |env_file|
          spec_env = load_yaml(env_file)

          name = spec_env['name'] || 'default'

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
      config['env_partial_patterns'].each do |pattern|
        pattern = File.join(config['working_dir'] || Dir.pwd, pattern)

        Dir.glob(pattern).each do|env_file|
          partial_env = load_yaml(env_file)
          name = partial_env.delete('name') || 'default'
          next unless @envs.key? name

          @envs[name].deep_merge!(partial_env)
        end
      end

      self
    end

    private

    def load_yaml file_path
      yaml = File.read(file_path)
      YAML.safe_load(yaml, aliases: true) || {}
    end
  end
end
