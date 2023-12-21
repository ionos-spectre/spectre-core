require 'ostruct'
require 'yaml'
require 'json'
require 'optparse'
require 'ectoplasm'
require 'date'
require 'fileutils'
require 'securerandom'

require_relative 'spectre/version'
require_relative 'spectre/assertion'

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
  class FileLogger
    def initialize name
      @name = name
      @log_file = nil
      @debug = CONFIG['debug']

      now = DateTime.now

      if CONFIG.key? 'log_file'
        @log_file = CONFIG['log_file'].frmt({
          shortdate: now.strftime('%Y-%m-%d'),
          date: now.strftime('%Y-%m-%d_%H%M%S'),
          timestamp: now.strftime('%s'),
        })

        log_dir = File.dirname(@log_file)
        FileUtils.makedirs(log_dir)
      end
    end

    def scope desc, subject, type
      write_to_file(DateTime.now, :debug, "# BEGIN #{type} [#{subject.name}] #{desc}", nil, nil)

      yield

      write_to_file(DateTime.now, :debug, "# END #{type} [#{subject.name}] #{desc}", nil, nil)
    end

    def log level, message, status=nil, desc=nil, timestamp=nil
      if block_given?
        level, status, desc = yield
      end

      timestamp = timestamp || DateTime.now

      write_to_file(timestamp, level, message, status, desc)

      RunContext.current.log(timestamp, @name, level, message, status, desc) unless RunContext.current.nil?

      [level, status, desc]
    end

    %i{debug info warn}.each do |method|
      define_method(method) do |message|
        log(method, message)
      end
    end

    private

    def write_to_file timestamp, level, message, status, desc
      return if @log_file.nil?
      return unless @debug or level != :debug

      line = "[#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%6N%:z')}] #{level.to_s.upcase.rjust(5, ' ')} -- #{@name}: #{message}"
      line += "...[#{status}]" unless status.nil?
      line += " - #{desc}" unless desc.nil?
      line += "\n"
      File.write(@log_file, line, mode: 'a')
    end
  end

  class ConsoleFormatter < FileLogger
    def self.report runs
      errors = runs.count { |x| !x.error.nil? }
      failed = runs.count { |x| !x.failure.nil? }
      skipped = runs.count { |x| x.skipped }
      succeded = runs.count - errors - failed - skipped

      output = ''

      output += "\n#{succeded} succeded #{failed} failures #{errors} errors #{skipped} skipped\n\n".send(errors + failed > 0 ? :red : :green)

      runs.select { |x| !x.error.nil? or !x.failure.nil? }.each_with_index do |run, index|
        output += "#{index+1}) #{run.parent.full_desc} (#{(run.finished - run.started).duration}) [#{run.parent.name}]".red
        output += "\n"

        if run.error
          error_output = "but an unexpected error occurred during run\n"
          file, line = get_error_info(run.error)

          error_output += "  file.....: #{file}:#{line}\n"
          error_output += "  type.....: #{run.error.class.name}\n"
          error_output += "  message..: #{run.error.message}\n"

          if CONFIG['debug']
            error_output += "  backtrace:\n"

            run.error.backtrace.each do |trace|
              error_output += "    #{trace}\n"
            end
          end

          output += error_output.indent(5).red
          output += "\n\n"
        end

        if run.failure
          output += "     #{run.failure.red}\n\n"
        end
      end

      puts output
    end

    def self.list
      specs = CONTEXTS.map do |context|
        context.all_specs
      end.flatten

      colors = [:blue, :magenta, :yellow, :green]
      counter = 0

      specs
        .group_by { |x| x.parent.root }
        .each do |_context, spec_group|
          spec_group.each do |spec|
            spec_id = "[#{spec.name}]".send(colors[counter % colors.length])
            puts "#{spec_id} #{spec.full_desc} #{spec.tags.map { |x| "##{x}" }.join(' ').cyan }"
          end

          counter += 1
        end
    end

    def initialize name
      super(name)

      @level = 0
      @width = 60
      @indent = 2
    end

    def scope desc, subject, type, &block
      if desc
        if [:before, :after, :setup, :teardown].include?(type)
          colored_desc = desc.magenta
        elsif type == :group
          colored_desc = desc.grey
        elsif type == :spec
          colored_desc = desc.cyan
        elsif type == :context
          colored_desc = desc.blue
        end

        write(colored_desc)
        puts
      end

      if block_given?
        @level += 1

        begin
          super(desc, subject, type, &block)
        ensure
          @level -= 1
        end
      end
    end

    def log level, message, status=nil, desc=nil, &block
      write(message, true) if block_given? or @debug or level != :debug

      level, status, desc = super(level, message, status, desc, &block)

      label = status || level

      return unless block_given? or @debug or level != :debug

      status_text = "[#{label}]"

      if desc.nil?
        puts status_text.send(label)
      else
        puts "#{status_text} - #{desc}".send(label)
      end
    end

    private

    def indent
      ' ' * (@level * @indent)
    end

    def write message, fill=false
      output = ''

      if message.nil? or message.empty?
        output = indent
        print output
      else
        message.lines.each do |line|
          output = indent + line
          print output
        end
      end

      print '.' * (@width - output.length) if fill
    end
  end

  class JsonFormatter < FileLogger
    def self.report runs
      reports = runs.map do |run|
        {
          id: run.id,
          parent: run.parent.id,
          status: run.error ? :error : (run.failure ? :failed : (run.skipped ? :skipped : :ok)),
          error: run.error,
          failure: run.failure,
          skipped: run.skipped,
          started: run.started,
          finished: run.finished,
          logs: run.logs,
        }
      end

      puts reports.to_json
    end

    def self.list
      context_to_hash = proc do |context|
        {
          name: context.name,
          desc: context.desc,
          children: context.children.map(&context_to_hash),
          specs: context.specs.map do |spec|
            {
              name: spec.name,
              desc: spec.desc,
              tags: spec.tags,
            }
          end,
        }
      end

      puts CONTEXTS.map(&context_to_hash).to_json
    end

    def initialize name
      super(name)
      @scope = nil
      $stdout.sync = true
    end

    def scope desc, subject, type, &block
      prev_scope = @scope
      @scope = SecureRandom.hex(5)

      log_entry = {
        id: @scope,
        scope: prev_scope,
        type: type,
        desc: desc,
      }

      puts log_entry.to_json

      super(desc, subject, type, &block)

      @scope = prev_scope
    end

    def log level, message, status=nil, desc=nil, &block
      timestamp = DateTime.now
      log_id = SecureRandom.hex(5)

      write_log(log_id, timestamp, level, message, status, desc)

      level, status, desc = super(level, message, status, desc, timestamp, &block)

      write_log(log_id, DateTime.now, level, message, status, desc) if block_given? and !status.nil?
    end

    private

    def write_log log_id, timestamp, level, message, status, desc
      log_entry = {
        id: log_id,
        scope: @scope,
        type: :log,
        timestamp: timestamp.strftime('%Y-%m-%dT%H:%M:%S.%6N%:z'),
        level: level,
        message: message,
        status: status,
        desc: desc,
      }

      puts log_entry.to_json
    end
  end

  class RunContext
    attr_reader :id, :name, :parent, :logs, :error, :failure, :skipped, :started, :finished

    @@current = nil

    def self.current
      @@current
    end

    def initialize parent, data
      @id = SecureRandom.hex(5)

      @parent = parent
      @data = data
      @logs = []

      @error = nil
      @failure = nil
      @skipped = false

      @started = Time.now

      begin
        @@current = self
        yield self
      ensure
        @finished = Time.now
        @@current = nil
      end
    end

    def fail_with message
      raise SpectreFailure.new(message)
    end

    def expect desc
      Spectre.logger.log(:debug, 'expect ' + desc) do
        result = [:debug, :ok, nil]

        begin
          yield
        rescue SpectreFailure => e
          @failure = "Expected #{desc}, but it failed with #{e.message}"
          result = [:error, :failed, nil]
        rescue Interrupt
          @skipped = true
          result = [:debug, :skipped, 'canceled by user']
        rescue Exception => e
          @error = e
          result = [:fatal, :error, e.class.name]
        end

        result
      end
    end

    def group desc
      Spectre.logger.scope(desc, @parent, :group) do
        yield
      end
    end

    def log timestamp, name, level, message, status, desc
      @logs << [timestamp, name, level, message, status, desc]
    end

    def run desc, with: []
      instance_exec(*with, &MIXINS[desc])
    end

    alias :also :run

    def execute(&)
      begin
        instance_exec(@data, &)
      rescue SpectreFailure => e
        @failure = e.message
        Spectre.logger.log(:error, nil, :failed)
      rescue Interrupt
        Spectre.logger.log(:debug, nil, :skipped, 'canceled by user')
      rescue Exception => e
        Spectre.logger.log(:fatal, nil, :error, e.class.name)
        @error = e
      end
    end
  end

  class TestSpecification
    attr_reader :id, :name, :desc, :parent, :tags, :data

    def initialize parent, name, desc, tags, data, block
      @id = SecureRandom.hex(5)
      @parent = parent
      @name = name
      @desc = desc
      @tags = tags
      @data = data || [nil]
      @block = block
    end

    def full_desc
      @parent.full_desc + ' ' + @desc
    end

    def run befores, afters
      @data.map do |data|
        RunContext.new(self, data) do |run_context|
          Spectre.logger.scope('it ' + @desc, self, :spec) do
            begin
              if befores.any?
                Spectre.logger.scope('before', self, :before) do
                  befores.each do |block|
                    run_context.execute(&block)
                  end
                end
              end

              run_context.execute(&@block)
            ensure
              if afters.any?
                Spectre.logger.scope('after', self, :after) do
                  afters.each do |block|
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

  class DefinitionContext
    attr_reader :id, :name, :desc, :parent, :full_desc, :children, :specs

    def initialize desc, parent=nil
      @id = SecureRandom.hex(5)
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
      root_context = root
      name = "#{root_context.name}-#{root_context.all_specs.count + 1}"
      spec = TestSpecification.new(self, name, desc, tags, with, block)
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

      Spectre.logger.scope(@desc, self, :context) do
        setup_run = nil

        if @setups.any?
          setup_run = RunContext.new(self, nil) do |run_context|
            Spectre.logger.scope('setup', self, :setup) do
              @setups.each do |block|
                run_context.execute(&block)
              end
            end
          end

          runs << setup_run
        end

        # Only run specs if setup was successful
        if setup_run.nil? or setup_run.error.nil?
          runs += specs.map do |spec|
            spec.run(@befores, @afters)
          end
        end

        if @teardowns.any?
          runs << RunContext.new(self, nil) do |run_context|
            Spectre.logger.scope('teardown', self, :teardown) do
              @teardowns.each do |block|
                run_context.execute(&block)
              end
            end
          end
        end

        @children.each do |context|
          runs += context.run(spec_filter, tags)
        end
      end

      runs
    end

    private

    def tag? tags, tag_exp
      tags = tags.map { |x| x.to_s }
      all_tags = tag_exp.split('+')
      included_tags = all_tags.select { |x| !x.start_with? '!' }
      excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
      included_tags & tags == included_tags and excluded_tags & tags == []
    end
  end

  # Define default config

  CONFIG = {
    'config_file' => './spectre.yml',
    'log_file' => './logs/spectre_<date>.log',
    'formatter' => 'Spectre::ConsoleFormatter',
    'specs' => [],
    'tags' => [],
    'debug' => false,
    'env_patterns' => ['environments/**/*.env.yml'],
    'env_partial_patterns' => ['./environments/**/*.env.secret.yml'],
    'spec_patterns' => ['spec/**/*.spec.rb'],
    'mixin_patterns' => ['mixins/**/*.mixin.rb'],
    'resource_paths' => ['../common/resources', './resources'],
    'modules' => [],
    'colored' => true,
  }

  CONTEXTS = []
  MIXINS = {}
  RESOURCES = {}
  ENVIRONMENTS = {}

  BAG = OpenStruct.new

  DEFAULT_ENV_NAME = 'default'

  class << self
    attr_reader :env, :logger

    def setup config_overrides
      # Load global config file
      global_config_file = File.join(File.expand_path('~'), '.spectre')

      if File.exist? global_config_file
        global_config = load_yaml(global_config_file)
        CONFIG.deep_merge!(global_config)
      end

      # Load main spectre config
      main_config_file = File.join(Dir.pwd, CONFIG['config_file'])

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
          ENVIRONMENTS[env_name].deep_merge!(loaded_env) unless ENVIRONMENTS.key?(env_name)
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

      @logger = create_logger('spectre')
    end

    def create_logger name
      Object.const_get(CONFIG['formatter']).new(name)
    end

    def run
      CONTEXTS.map do |context|
        context.run(CONFIG['specs'], CONFIG['tags'])
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

    def bag
      BAG
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
%i{env describe bag mixin resources}.each do |method|
  define_method(method) do |*args, &block|
    Spectre.send(method, *args, &block)
  end
end

%i{debug info warn}.each do |method|
  define_method(method) do |*args, &block|
    Spectre.logger.send(method, *args, &block)
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

  opts.on('--logger NAME', 'Use specified logger') do |class_name|
    Spectre::CONFIG['logger'] = class_name
  end

  opts.on('--reporter NAME', 'Use specified reporter') do |class_name|
    Spectre::CONFIG['reporter'] = class_name
  end

  opts.on('--json', 'Use JSON formatter') do
    Spectre::CONFIG['formatter'] = 'Spectre::JsonFormatter'
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
    index = option.index('=')
    key = option[0...index]
    val = option[index+1..-1]

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
  Spectre.logger.class.list
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

  Spectre.logger.class.report(runs)
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
