require 'date'
require 'yaml'

module Spectre
  module Environment
    class << self
      @envs = {}
      @config = {}

      def envs
        @envs
      end

      def env
        bucket(:spectre_env)
      end

      def bucket name
        val = Thread.current[name]

        return val unless val.nil?

        Thread.current[:parent].nil? ? nil : Thread.current[:parent][name]
      end

      def put name, val
        Thread.current[name] = val
      end

      def delete name
        Thread.current[name] = nil
      end

      def is_defined? name
        not Thread.current[name].nil?
      end

      def select name=nil
        name = name || 'default'

        config = @config
          .deep_clone
          .deep_merge(@envs[name] || {})

        put(:spectre_env, config.to_recursive_struct.freeze)

        config
      end

      def load config
        @envs = {}
        @config = config

        read_env_files = {}

        @config['env_patterns'].each do |pattern|
          pattern = File.join(@config['working_dir'], pattern)

          Dir.glob(pattern).each do |env_file|
            spec_env = load_yaml(env_file)

            name = spec_env['name'] || 'default'

            if @envs.key? name
              existing_env_file = read_env_files[name]
              puts "Duplicate environment definition detected with name #{name} in '#{f}'. Previously defined in '#{existing_env_file}'"
              exit 1
            end

            read_env_files[name] = env_file
            @envs[name] = spec_env
          end
        end

        # Merge partial environment configs with existing environments
        @config['env_partial_patterns'].each do |pattern|
          pattern = File.join(@config['working_dir'], pattern)

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
end