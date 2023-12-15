require 'ostruct'
require 'yaml'

def get_error_info error
  non_spectre_files = error.backtrace.select { |x| !x.include? 'lib/spectre' }

  if non_spectre_files.count > 0
    causing_file = non_spectre_files.first
  else
    causing_file = error.backtrace[0]
  end

  matches = causing_file.match(/(.*\.rb):(\d+)/)

  return {} unless matches

  file, line = matches.captures
  file.slice!(Dir.pwd + '/')

  {
    file: file,
    line: line,
    type: error.class,
    message: error.message,
    backtrace: error.backtrace,
  }
end

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
  @@colored = false

  def self.colored!
    @@colored = true
  end

  def white; self; end

  def red; colored '31'; end

  def green; colored '32'; end

  def yellow; colored '33'; end

  def blue; colored '34'; end

  def magenta; colored '35'; end

  def cyan; colored '36'; end

  def grey; colored '90'; end

  def bold; colored '1'; end

  def underline; colored '4'; end

  def indent amount
    self.lines.map { |line| (' ' * amount) + line }.join
  end

  private

  def colored ansi_color
    return self unless @@colored

    "\e[#{ansi_color}m#{self}\e[0m"
  end

  alias :error :red
  alias :failed :red
  alias :warn :yellow
  alias :ok :green
  alias :info :blue
  alias :skipped :grey
end

class ConsoleLogger
  def initialize
    @level = 0
    @width = 60
    @indent = 2
  end

  def log message, subject
    if message
      if subject.is_a? DefinitionContext
        message = message.blue
      elsif subject.is_a? TestSpecification
        if ['before', 'after'].include? message
          message = message.magenta
        else
          message = message.cyan
        end
      end

      write(message)
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

  def progress message
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

    @started = nil
    @finished = nil
  end

  def info message
    LOGGER.progress(message) { [:info, nil] }
  end

  def fail_with message
    raise SpectreFailure.new(message)
  end

  def expect desc
    LOGGER.progress('expect ' + desc) do
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

  def run(&)
    begin
      instance_exec(@data, &)
    rescue Interrupt
      LOGGER.progress('') { [:skipped, 'canceled by user'] }
    rescue Exception => e
      @error = e
    end
  end

  def record
    @started = Time.now

    begin
      yield
    ensure
      @finished = Time.now
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
    # specs = @specs.select { |spec| tags.empty? or spec.tags.any? { |tag| tags.include? tag } }

    specs = @specs.select do |spec|
      (spec_filter.empty? and tags.empty?) or (spec_filter.any? { |x| spec.name.match?('^' + x.gsub('*', '.*') + '$') }) or (tags.any? { |x| tag?(spec.tags, x) })
    end

    return [] if specs.empty?

    runs = []

    LOGGER.log(@desc, self) do
      if @setups.any?
        LOGGER.log('setup', self) do
          @setups.each do |block|
            instance_eval(&block)
          end
        end
      end

      runs = specs.map do |spec|
        spec.run
      end

      if @teardowns.any?
        LOGGER.log('teardown', self) do
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
      run_context = RunContext.new(self, data)

      run_context.record do
        LOGGER.log('it ' + @desc, self) do
          begin
            if @befores.any?
              LOGGER.log('before', self) do
                @befores.each do |block|
                  run_context.run(&block)
                end
              end
            end

            run_context.run(&@block)
          ensure
            if @afters.any?
              LOGGER.log('after', self) do
                @afters.each do |block|
                  run_context.run(&block)
                end
              end
            end
          end
        end
      end

      run_context
    end
  end
end

CONFIG = {
  'env' => 'default',
  'env_patterns' => ['environments/**/*.env.yml'],
  'env_partial_patterns' => ['./environments/**/*.env.secret.yml'],
  'spec_patterns' => ['spec/**/*.spec.rb'],
  'mixin_patterns' => ['mixins/**/*.mixin.rb'],
  'resource_paths' => ['../common/resources', './resources'],
}

ENV = OpenStruct.new(CONFIG).freeze

CONTEXTS = []
LOGGER = ConsoleLogger.new
MIXINS = {}
RESOURCES = {}
ENVIRONMENTS = {}

DEFAULT_ENV_NAME = 'default'

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
CONFIG.deep_merge!(ENVIRONMENTS[CONFIG['env'] || DEFAULT_ENV_NAME])

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

# Define global available methods and properties

def env
  ENV
end

def describe(name, &)
  main_context = DefinitionContext.new(name)
  main_context.instance_eval(&)
  CONTEXTS << main_context
end

def mixin desc, &block
  MIXINS[desc] = block
end

# Load specs
load_files(CONFIG['spec_patterns'])
CONTEXTS.freeze

# Load mixins
load_files(CONFIG['mixin_patterns'])
MIXINS.freeze

String.colored!

spec_filter = []
tags = []

action = ARGV[0] || 'run'

# List specs
if action == 'list'
  specs = CONTEXTS.map do |context|
    context.all_specs
  end.flatten

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

# Run specs
if action == 'run'
  runs = CONTEXTS.map do |context|
    context.run(spec_filter, tags)
  end.flatten

  errors = runs.count { |x| !x.error.nil? }
  failed = runs.count { |x| !x.failure.nil? }
  skipped = runs.count { |x| x.skipped }
  succeded = runs.count - errors - failed - skipped

  puts "\n#{succeded} succeded #{failed} failures #{errors} errors #{skipped} skipped\n".send(errors + failed > 0 ? :red : :green)

  runs.select { |x| !x.error.nil? or !x.failure.nil? }.each_with_index do |run, index|
    puts "#{index+1}) #{run.spec.full_desc} [#{run.spec.name}]".red

    if run.error
      str = "but an unexpected error occurred during run\n"
      error_info = get_error_info(run.error)

      str += "  file.....: #{error_info[:file]}\n"
      str += "  type.....: #{error_info[:type]}\n"
      str += "  message..: #{error_info[:message]}\n"

      # str += "  backtrace:\n"
      # error_info[:backtrace].each do |line|
      #   str += "    #{line}\n"
      # end

      puts str.indent(5).red
    end

    if run.failure
      expected, failure = run.failure

      puts "     Expected #{expected} but it failed with:\n     #{failure}\n".red
    end
  end
end
