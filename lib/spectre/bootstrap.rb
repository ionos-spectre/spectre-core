require_relative '../spectre'

module Spectre::Bootstrap
  DEFAULT_CONFIG = {
    'project' => nil,
    'working_dir' => Dir.pwd,
    'config_file' => './spectre.yml',
    'environment' => 'default',
    'specs' => [],
    'tags' => [],
    'colored' => true,
    'verbose' => false,
    'log_file' => './logs/spectre_<date>.log',
    'debug' => false,
    'out_path' => './reports',
    'secure_keys' => ['password', 'secret', 'token', 'secure', 'authorization'],
    'spec_patterns' => ['./specs/**/*.spec.rb'],
    'mixin_patterns' => ['../common/mixins/**/*.mixin.rb', './mixins/**/*.mixin.rb'],
    'env_patterns' => ['./environments/**/*.env.yml'],
    'env_partial_patterns' => ['./environments/**/*.env.secret.yml'],
    'resource_paths' => ['../common/resources', './resources'],
    'modules' => [
      'spectre/helpers',
      'spectre/reporter/console',
      'spectre/eventing/console',
      'spectre/logging',
      'spectre/logging/file',
      'spectre/assertion',
      'spectre/diagnostic',
      'spectre/environment',
      'spectre/mixin',
      'spectre/http',
      'spectre/http/basic_auth',
      'spectre/http/keystone',
      'spectre/resources',
      'spectre/async',
    ],
    'include' => [],
    'exclude' => [],
  }

  class << self
    @config = {}
    @envs = {}

    def load
      load_config()
      load_envs()
      self
    end

    def load_config
      @config = DEFAULT_CONFIG.deep_clone

      # Load global config file first
      global_config_file = File.join(File.expand_path('~'), '.spectre')

      if File.exists? global_config_file
        global_options = load_yaml(global_config_file)
        @config.deep_merge!(global_options) if global_options
      end

      # Then load local config file
      config_file = @config['config_file']

      if File.exists? config_file
        file_options = load_yaml(config_file)
        @config.deep_merge!(file_options)
        @config['working_dir'] = File.expand_path File.dirname(config_file)
      end

      # Set config options, which are only allowed to be overriden by command options
      @config['debug'] = DEFAULT_CONFIG['debug']

      # Set project name
      @config['project'] = File.basename(@config['working_dir']) unless @config['project']
    end

    def load_envs
      @envs = {}

      read_env_files = {}

      @config['env_patterns'].each do |pattern|
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
        Dir.glob(pattern).each do|env_file|
          partial_env = load_yaml(env_file)
          name = partial_env.delete('name') || 'default'
          next unless @envs.key? name

          @envs[name].deep_merge!(partial_env)
        end
      end
    end

    def get_env name=nil
      name = name || 'default'

      @config
        .deep_clone
        .deep_merge(@envs[name] || {})
    end

    def load_specs config
      return unless config.key? 'spec_patterns'

      config['spec_patterns'].each do |pattern|
        Dir.glob(pattern).each do|f|
          require_relative File.join(config['working_dir'], f)
        end
      end
    end

    def load_mixins config
      return unless config.key? 'mixin_patterns'

      config['mixin_patterns'].each do |pattern|
        Dir.glob(pattern).each do|f|
          require_relative File.join(config['working_dir'], f)
        end
      end
    end

    def load_modules config
      return unless config.key? 'modules'

      config['modules']
        .concat(config['include'] || [])
        .select { |mod| !(config['exclude'] || []).include? mod }
        .each do |mod|
          begin
            mod_file = mod + '.rb'
            spectre_lib_mod = File.join(File.dirname(__dir__), 'lib', mod_file)

            if File.exists? mod_file
              require_relative mod_file

            elsif File.exists? spectre_lib_mod
              require_relative spectre_lib_mod

            else
              require mod
            end
          rescue LoadError => e
            puts "Unable to load module #{mod}. Check if the module exists or remove it from your spectre config:\n#{e.message}"
            exit 1
          end
        end
    end

    private

    def load_yaml file_path
      yaml = File.read(file_path)
      YAML.safe_load(yaml, aliases: true) || {}
    end
  end
end