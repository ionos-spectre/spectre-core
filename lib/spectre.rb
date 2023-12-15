require 'ostruct'
require 'yaml'
require 'optparse'
require 'ectoplasm'

require_relative 'spectre/version'

class Hash
  def deep_merge!(second)
    return unless second.is_a?(Hash)

    merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge!(v2, &merger) : v2 }
    self.merge!(second, &merger)
  end

  def deep_freeze
    self
      .to_h { |key, val| [key, val.deep_freeze] }
      .freeze
  end

  def to_recursive_struct
    OpenStruct.new(
      self.each_with_object({}) do |(key, val), memo|
        memo[key] = val.is_a?(Hash) ? val.to_recursive_struct : val
      end
    )
  end
end

class Array
  def deep_freeze
    self.map { |x| x.deep_freeze }
  end
end

class Object
  def deep_freeze
    self.freeze
  end

  def deep_clone
    Marshal.load(Marshal.dump(self))
  end
end

class String
  alias :error :red
  alias :failed :red
  alias :warn :yellow
  alias :ok :green
  alias :info :blue
  alias :debug :grey
  alias :skipped :grey
end

module Spectre
  class ConsoleLogger
    def initialize
      @level = 0
      @width = 60
      @indent = 2
    end

    def scope desc, subject
      if desc
        if subject.is_a? DefinitionContext
          desc = desc.blue
        elsif subject.is_a? TestSpecification
          if ['before', 'after'].include? desc
            desc = desc.magenta
          else
            desc = desc.cyan
          end
        end

        write(desc)
        puts
      end

      if block_given?
        @level += 1

        begin
          yield
        ensure
          @level -= 1
        end
      end
    end

    def log message
      output_len = write(message)
      result = yield
      print '.' * (@width - output_len)

      status = result[0]

      status_text = "[#{result[0]}]"

      if result[1].nil?
        puts status_text.send(status)
      else
        puts "#{status_text} - #{result[1]}".send(status)
      end
    end

    private

    def indent
      ' ' * (@level * @indent)
    end

    def write message
      output = ''

      if message.empty?
        output = indent
        print output
      else
        message.lines.each do |line|
          output = indent + line
          print output
        end
      end

      output.length
    end
  end

  class SpectreFailure < Exception
  end

  class RunContext
    attr_reader :spec, :error, :failure, :skipped, :started, :finished

    def initialize spec, data
      @spec = spec
      @data = data

      @error = nil
      @failure = nil
      @skipped = false

      @started = Time.now

      begin
        yield self
      ensure
        @finished = Time.now
      end
    end

    %i{debug info warn}.each do |method|
      define_method(method) do |message|
        LOGGER.log(message) { [method, nil] }
      end
    end

    def fail_with message
      raise SpectreFailure.new(message)
    end

    def expect desc
      LOGGER.log('expect ' + desc) do
        result = [:ok, nil]

        begin
          yield
        rescue SpectreFailure => e
          @failure = [desc, e.message]
          result = [:failed, nil]
        rescue Interrupt
          @skipped = true
          result = [:skipped, 'canceled by user']
        rescue Exception => e
          @error = e
          result = [:error, e.class.name]
        end

        result
      end
    end

    def run desc, with: []
      instance_exec(*with, &MIXINS[desc])
    end

    alias :also :run

    def execute(&)
      begin
        instance_exec(@data, &)
      rescue Interrupt
        LOGGER.log('') { [:skipped, 'canceled by user'] }
      rescue Exception => e
        @error = e
      end
    end
  end

  class DefinitionContext
    attr_reader :parent, :name, :desc, :full_desc, :children, :specs

    def initialize desc, parent=nil
      @parent = parent
      @desc = desc
      @children = []
      @specs = []

      @setups = []
      @teardowns = []

      @befores = []
      @afters = []

      @name = @desc.downcase.gsub(/[^a-z0-9]+/, '_')
    end

    def full_desc
      return @desc unless @parent

      @parent.full_desc + ' ' + @desc
    end

    def root
      @parent ? @parent.root : self
    end

    def all_specs
      @specs + @children.map { |x| x.all_specs }.flatten
    end

    def context(desc, &)
      context = DefinitionContext.new(desc, self)
      @children << context
      context.instance_eval(&)
    end

    def setup &block
      @setups << block
    end

    def teardown &block
      @teardowns << block
    end

    def before &block
      @befores << block
    end

    def after &block
      @afters << block
    end

    def it desc, tags: [], with: nil, &block
      spec = TestSpecification.new(self, desc, tags, with, block, @befores, @afters)
      @specs << spec
    end

    def run spec_filter=[], tags=[]
      specs = @specs.select do |spec|
        (spec_filter.empty? and tags.empty?) or
        (spec_filter.any? { |x| spec.name.match?('^' + x.gsub('*', '.*') + '$') }) or
        (tags.any? { |x| tag?(spec.tags, x) })
      end

      return [] if specs.empty?

      runs = []

      LOGGER.scope(@desc, self) do
        if @setups.any?
          LOGGER.scope('setup', self) do
            @setups.each do |block|
              instance_eval(&block)
            end
          end
        end

        runs = specs.map do |spec|
          spec.run
        end

        if @teardowns.any?
          LOGGER.scope('teardown', self) do
            @teardowns.each do |block|
              instance_eval(&block)
            end
          end
        end

        @children.each do |context|
          runs = runs + context.run(spec_filter, tags)
        end
      end

      runs
    end
  end

  class TestSpecification
    attr_reader :context, :name, :desc, :tags, :data

    def initialize context, desc, tags, data, block, befores, afters
      @context = context
      @desc = desc
      @tags = tags
      @data = data || [nil]

      @block = block
      @befores = befores
      @afters = afters

      root_context = context.root

      @name = "#{root_context.name}-#{root_context.all_specs.count + 1}"
    end

    def full_desc
      @context.full_desc + ' ' + @desc
    end

    def run
      @data.map do |data|
        RunContext.new(self, data) do |run_context|
          LOGGER.scope('it ' + @desc, self) do
            begin
              if @befores.any?
                LOGGER.scope('before', self) do
                  @befores.each do |block|
                    run_context.execute(&block)
                  end
                end
              end

              run_context.execute(&@block)
            ensure
              if @afters.any?
                LOGGER.scope('after', self) do
                  @afters.each do |block|
                    run_context.execute(&block)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # Define default config

  CONFIG = {
    'specs' => [],
    'tags' => [],
    'env_patterns' => ['environments/**/*.env.yml'],
    'env_partial_patterns' => ['./environments/**/*.env.secret.yml'],
    'spec_patterns' => ['spec/**/*.spec.rb'],
    'mixin_patterns' => ['mixins/**/*.mixin.rb'],
    'resource_paths' => ['../common/resources', './resources'],
    'modules' => [],
    'colored' => true,
  }

  CONTEXTS = []
  LOGGER = ConsoleLogger.new
  MIXINS = {}
  RESOURCES = {}
  ENVIRONMENTS = {}

  DEFAULT_ENV_NAME = 'default'

  class << self
    attr_reader :env

    def setup config_overrides
      # Load global config file
      global_config_file = File.join(File.expand_path('~'), '.spectre')

      if File.exist? global_config_file
        global_config = load_yaml(global_config_file)
        CONFIG.deep_merge!(global_config)
      end

      # Load main spectre config
      main_config_file = File.join(Dir.pwd, 'spectre.yml')

      if File.exist? main_config_file
        main_config = load_yaml(main_config_file)
        CONFIG.deep_merge!(main_config)
      end

      # Load environments
      CONFIG['env_patterns'].each do |pattern|
        Dir.glob(pattern).each do |file_path|
          loaded_env = load_yaml(file_path)
          env_name = loaded_env['name'] || DEFAULT_ENV_NAME
          ENVIRONMENTS[env_name] = loaded_env
        end
      end

      CONFIG['env_partial_patterns'].each do |pattern|
        Dir.glob(pattern).each do |file_path|
          loaded_env = load_yaml(file_path)
          env_name = loaded_env['name'] || DEFAULT_ENV_NAME
          ENVIRONMENTS[env_name].deep_merge!(loaded_env)
        end
      end

      # Select environment and merge it
      CONFIG.deep_merge!(ENVIRONMENTS[CONFIG.delete('selected_env') || DEFAULT_ENV_NAME])

      # Merge property overrides
      CONFIG.deep_merge!(config_overrides)

      # Load resources
      CONFIG['resource_paths'].each do |resource_path|
        resource_files = Dir.glob File.join(resource_path, '**/*')

        resource_files.each do |file|
          file.slice! resource_path
          file = file[1..-1]
          RESOURCES[file] = File.expand_path File.join(resource_path, file)
        end
      end

      # Load modules
      CONFIG['modules'].each do |module_name|
        module_path = File.join(Dir.pwd, module_name)

        if File.exist? module_path
          require_relative module_path
        else
          require module_name
        end
      end

      # Load specs
      load_files(CONFIG['spec_patterns'])
      CONTEXTS.freeze

      # Load mixins
      load_files(CONFIG['mixin_patterns'])
      MIXINS.freeze

      @env = OpenStruct.new(CONFIG).freeze
    end

    def run
      CONTEXTS.map do |context|
        context.run(CONFIG['specs'], CONFIG['tags'])
      end.flatten
    end

    def list
      CONTEXTS.map do |context|
        context.all_specs
      end.flatten
    end

    def describe(name, &)
      main_context = DefinitionContext.new(name)
      main_context.instance_eval(&)
      CONTEXTS << main_context
    end

    def mixin desc, &block
      MIXINS[desc] = block
    end

    def resources path
      RESOURCES[path]
    end

    private

    def load_files patterns
      patterns.each do |pattern|
        Dir.glob(pattern).each do |file|
          require_relative File.join(Dir.pwd, file)
        end
      end
    end

    def load_yaml file_path
      file_content = File.read(file_path)
      YAML.safe_load(file_content, aliases: true) || {}
    end
  end
end

# Expose spectre methods
%i{env describe mixin resources}.each do |method|
  define_method(method) do |*args, &block|
    Spectre.send(method, *args, &block)
  end
end

# Define command line arguments

config_overrides = {}

OptionParser.new do |opts|
  opts.banner = <<~BANNER
    Spectre #{Spectre::VERSION}

    Usage: spectre [command] [options]

      Commands:
        run         Run specs (default)
        list        List specs
        show        Print current environment settings
        dump        Dumps the given environment in YAML format to console
        cleanup     Will remove all generated files (e.g. logs and reports)
        init        Initializes a new spectre project

      Specific options:
  BANNER

  opts.on('-s SPEC,SPEC', '--specs SPEC,SPEC', Array, 'The specs to run') do |specs|
    Spectre::CONFIG['specs'] = specs
  end

  opts.on('-t TAG,TAG', '--tags TAG,TAG', Array, 'Run only specs with given tags') do |tags|
    Spectre::CONFIG['tags'] = tags
  end

  opts.on('-e NAME', '--env NAME', 'Name of the environment to load') do |env_name|
    Spectre::CONFIG['selected_env'] = env_name
  end

  opts.on('-c FILE', '--config FILE', 'Config file to load') do |file_path|
    Spectre::CONFIG['config_file'] = file_path
  end

  opts.on('--spec-pattern PATTERN', Array, 'File pattern for spec files') do |spec_pattern|
    Spectre::CONFIG['spec_patterns'] = spec_pattern
  end

  opts.on('--env-pattern PATTERN', Array, 'File pattern for environment files') do |env_patterns|
    Spectre::CONFIG['env_patterns'] = env_patterns
  end

  opts.on('--no-color', 'Disable colored output') do
    Spectre::CONFIG['colored'] = false
  end

  opts.on('--ignore-failure', 'Always exit with code 0') do
    Spectre::CONFIG['ignore_failure'] = true
  end

  opts.on('-o PATH', '--out PATH', 'Output directory path') do |path|
    Spectre::CONFIG['out_path'] = File.absolute_path(path)
  end

  opts.on('-m MODULE,MODULE', '--modules MODULE,MODULE', Array, "Load the given modules") do |modules|
    Spectre::CONFIG['modules'] += modules
  end

  opts.on('-d', '--debug', "Run in debug mode. Do not use in production!") do
    Spectre::CONFIG['debug'] = true
  end

  opts.on('-p KEY=VAL', '--property KEY=VAL', "Override config option. Use `spectre show` to get list of available options") do |option|
    key, val = option.split('=')
    val = val.split(',') if Spectre::CONFIG[key].is_a? Array
    val = ['true', '1'].include? val if [true, false].include?(Spectre::CONFIG[key])
    val = val.to_i if Spectre::CONFIG[key].is_a? Integer

    opt_path = key.split('.')

    curr_opt = config_overrides

    opt_path.each_with_index do |part, i|
      if i == opt_path.count-1
        curr_opt[part] = val
        break
      end

      curr_opt[part] = {} unless curr_opt.key?(part)
      curr_opt = curr_opt[part]
    end
  end

  opts.separator "\n  Common options:"

  opts.on_tail('-v', '--version', 'Print current installed version') do
    puts Spectre::VERSION
    exit
  end

  opts.on_tail('-h', '--help', 'Print this help') do
    puts opts
    exit
  end
end.parse!

# Setup spectre
Spectre.setup(config_overrides)

# Set colored output
String.colored! if Spectre::CONFIG['colored']

# Determine action
action = ARGV[0] || 'run'

# List specs
if action == 'list'
  specs = Spectre.list

  colors = [:blue, :magenta, :yellow, :green]
  counter = 0

  specs
    .group_by { |x| x.context.root }
    .each do |_context, spec_group|
      spec_group.each do |spec|
        spec_id = "[#{spec.name}]".send(colors[counter % colors.length])
        puts "#{spec_id} #{spec.full_desc} #{spec.tags.map { |x| "##{x}" }.join(' ').cyan }"
      end

      counter += 1
    end
end

def get_error_info error
  non_spectre_files = error.backtrace.select { |x| !x.include? 'lib/spectre' }

  if non_spectre_files.count > 0
    causing_file = non_spectre_files.first
  else
    causing_file = error.backtrace[0]
  end

  matches = causing_file.match(/(.*\.rb):(\d+)/)

  return unless matches

  file, line = matches.captures
  file.slice!(Dir.pwd + '/')

  return file, line
end

# Run specs
if action == 'run'
  runs = Spectre.run

  errors = runs.count { |x| !x.error.nil? }
  failed = runs.count { |x| !x.failure.nil? }
  skipped = runs.count { |x| x.skipped }
  succeded = runs.count - errors - failed - skipped

  puts "\n#{succeded} succeded #{failed} failures #{errors} errors #{skipped} skipped\n".send(errors + failed > 0 ? :red : :green)

  runs.select { |x| !x.error.nil? or !x.failure.nil? }.each_with_index do |run, index|
    puts "#{index+1}) #{run.spec.full_desc} (#{(run.finished - run.started).duration}) [#{run.spec.name}]".red

    if run.error
      str = "but an unexpected error occurred during run\n"
      file, line = get_error_info(run.error)

      str += "  file.....: #{file}:#{line}\n"
      str += "  type.....: #{run.error.class.name}\n"
      str += "  message..: #{run.error.message}\n"

      # str += "  backtrace:\n"
      # run.error.backtrace.each do |line|
      #   str += "    #{line}\n"
      # end

      puts str.indent(5).red
      puts
    end

    if run.failure
      expected, failure = run.failure

      puts "     Expected #{expected} but it failed with:\n     #{failure}\n".red
    end
  end
end

if action == 'show'
  puts Spectre::CONFIG.pretty
end


DEFAULT_SPECTRE_CFG = %{log_file: ./logs/spectre_<date>.log
env_patterns:
  - './environments/**/*.env.yml'
env_partial_patterns:
  - './environments/**/*.env.secret.yml'
spec_patterns:
  - './specs/**/*.spec.rb'
mixin_patterns:
  - '../common/**/*.mixin.rb'
  - './mixins/**/*.mixin.rb'
resource_paths:
  - '../common/resources'
  - './resources'
}


DEFAULT_ENV_CFG = %{cert: &cert ./resources/<root_cert>.cer
http:
  <http_client_name>:
    base_url: http://localhost:5000/api/v1/
    # basic_auth:
      # username: <username>
      # password: <password>
    # keystone:
      # url: https://<keystone_url>/main/v3/
      # username: <username>
      # password: <password>
      # project: <project>
      # domain: <domain>
      # cert: *cert
# ssh:
  # <ssh_client_name>:
    # host: <hostname>
    # username: <username>
    # password: <password>
}

DEFAULT_ENV_SECRET_CFG = %{http:
  <http_client_name>:
    # basic_auth:
      # username: <username>
      # password: <password>
    # keystone:
      # username: <username>
      # password: <password>
# ssh:
  # <ssh_client_name>:
    # username: <username>
    # password: <password>
}

SAMPLE_SPEC = %[describe '<subject>' do
  it 'does some http requests', tags: [:sample] do
    log 'doing some http request'

    http '<http_client_name>' do
      auth 'basic'
      # auth 'keystone'
      method 'GET'
      path 'path/to/resource'
      param 'id', 4295118773
      param 'foo', 'bar'
      header 'X-Correlation-Id', '4c2367b1-bfee-4cc2-bdc5-ed17a6a9dd4b'
      header 'Range', 'bytes=500-999'
      json({
        "message": "Hello Spectre!"
      })
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'a message to exist' do
      response.json.message.should_not_be_empty
    end
  end
end
]

DEFAULT_GITIGNORE = %[*.code-workspace
logs/
reports/
**/environments/*.env.secret.yml
]

DEFAULT_GEMFILE = %[source 'https://rubygems.org'

gem 'spectre-core', '>= #{Spectre::VERSION}'
# gem 'spectre-mysql', '>= 2.0.0'
# gem 'spectre-ssh', '>= 2.0.0'
# gem 'spectre-ftp', '>= 2.0.0'
# gem 'spectre-curl', '>= 2.0.0'
# gem 'spectre-git', '>= 2.0.0'
# gem 'spectre-rabbitmq', '>= 2.0.0'
# gem 'spectre-reporter-junit', '>= 2.0.0'
# gem 'spectre-reporter-vstest', '>= 2.0.0'
# gem 'spectre-reporter-html', '>= 2.0.0'
]

if 'init' == action
  DEFAULT_FILES = [
    ['./environments/default.env.yml', DEFAULT_ENV_CFG],
    ['./environments/default.env.secret.yml', DEFAULT_ENV_SECRET_CFG],
    ['./specs/sample.spec.rb', SAMPLE_SPEC],
    ['./spectre.yml', DEFAULT_SPECTRE_CFG],
    ['./.gitignore', DEFAULT_GITIGNORE],
    ['./Gemfile', DEFAULT_GEMFILE],
  ]

  %w(environments logs specs).each do |dir_name|
    Dir.mkdir(dir_name) unless File.directory? dir_name
  end

  DEFAULT_FILES.each do |file, content|
    unless File.exist? file
      File.write(file, content)
    end
  end
end
