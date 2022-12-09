module Spectre::Config
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

    def load config_file=nil
      @config = DEFAULT_CONFIG.deep_clone

      # Load global config file first
      global_config_file = File.join(File.expand_path('~'), '.spectre')

      if File.exists? global_config_file
        global_options = load_yaml(global_config_file)
        @config.deep_merge!(global_options) if global_options
      end

      # Then load local config file
      config_file = config_file || @config['config_file']

      if File.exists? config_file
        file_options = load_yaml(config_file)
        @config.deep_merge!(file_options)
        @config['working_dir'] = File.expand_path File.dirname(config_file)
      end

      # Set config options, which are only allowed to be overriden by command options
      @config['debug'] = DEFAULT_CONFIG['debug']

      # Set project name
      @config['project'] = File.basename(@config['working_dir']) unless @config['project']

      @config
    end

    private

    def load_yaml file_path
      yaml = File.read(file_path)
      YAML.safe_load(yaml, aliases: true) || {}
    end
  end
end