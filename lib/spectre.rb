require 'ostruct'
require 'yaml'
require 'json'
require 'optparse'
require 'ectoplasm'
require 'date'
require 'fileutils'
require 'securerandom'

require_relative 'spectre/version'
require_relative 'spectre/expectation'

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

      if CONFIG['log_file']
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
      line += " [#{status}]" unless status.nil?
      line += " - #{desc}" unless desc.nil?
      line += "\n"
      File.write(@log_file, line, mode: 'a')
    end
  end

  class NoopFormatter
    def self.report runs
    end

    def self.list
    end

    def initialize name
      @name = name
    end

    %i{debug info warn}.each do |method|
      define_method(method) do |message|
        log(method, message)
      end
    end

    def log level, message, status=nil, desc=nil, timestamp=nil, &block
      return if @locked

      if block_given?
        @locked = true
        level, status, desc = yield
        @locked = false
      end

      timestamp = timestamp || DateTime.now

      RunContext.current.log(timestamp, @name, level, message, status, desc) unless RunContext.current.nil?

      [level, status, desc]
    end

    def scope desc, subject, type
      yield
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
      colors = [:blue, :magenta, :yellow, :green]
      counter = 0

      Spectre
        .list 
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
      @width = 80
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
        elsif type == :mixin
          colored_desc = desc.yellow
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
      return if @locked

      write(message, true) if block_given? or @debug or level != :debug

      @locked = true if block_given?

      level, status, desc = super(level, message, status, desc, &block)

      @locked = false if block_given?

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

      puts Spectre
        .list
        .group_by { |x| x.parent.root }
        .map(&context_to_hash).to_json
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
      raise Expectation::ExpectationFailure.new(message)
    end

    def expect desc
      Spectre.logger.log(:debug, "expect #{desc}") do
        result = [:debug, :ok, nil]

        begin
          yield
        rescue Expectation::ExpectationFailure => e
          @failure = "Expected #{desc}, but it failed with: #{e.message}"
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
      Spectre.logger.scope(desc, self, :mixin) do
        instance_exec(*with, &MIXINS[desc])
      end
    end

    alias :also :run

    def execute(&)
      begin
        instance_exec(@data, &)
      rescue Expectation::ExpectationFailure => e
        @failure = e.message
        Spectre.logger.log(:error, e.desc ? "expect #{e.desc}" : nil, :failed, e.actual ? "got #{e.actual}" : nil)
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
      context.instance_eval(&)
      @children << context
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
        if specs.any? and (setup_run.nil? or setup_run.error.nil?)
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
    'spec_patterns' => ['specs/**/*.spec.rb'],
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

      return self
    end

    def create_logger name
      Object.const_get(CONFIG['formatter']).new(name)
    end

    def list 
      spec_filter = CONFIG['specs']
      tag_filter = CONFIG['tags']

      CONTEXTS
        .map { |x| x.all_specs }
        .flatten
        .select do |spec|
          (spec_filter.empty? and tag_filter.empty?) or
          (spec_filter.empty? or spec_filter.any? { |x| spec.name.match?('^' + x.gsub('*', '.*') + '$') }) and
          (tag_filter.empty? or tag_filter.any? { |x| tag?(spec.tags, x) })
        end
    end

    def run
      list 
        .group_by { |x| x.parent.root }
        .map do |context, _specs|
          context.run
        end.flatten
    end

    def describe(name, &)
      # TODO check if context already exists and use it
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

    def tag? tags, tag_exp
      tags = tags.map { |x| x.to_s }
      all_tags = tag_exp.split('+')
      included_tags = all_tags.select { |x| !x.start_with? '!' }
      excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
      included_tags & tags == included_tags and excluded_tags & tags == []
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
  end
end
