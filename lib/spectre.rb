require 'ostruct'
require 'yaml'
require 'json'
require 'optparse'
require 'ectoplasm'
require 'date'
require 'fileutils'
require 'securerandom'
require 'logger'

require_relative 'spectre/version'
require_relative 'spectre/expectation'

def get_error_info error
  return unless error.backtrace

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

def tag? tags, tag_exp
  tags = tags.map { |x| x.to_s }
  all_tags = tag_exp.split('+')

  included_tags = all_tags.select { |x| !x.start_with? '!' }

  excluded_tags = all_tags
    .select { |x| x.start_with? '!' }
    .map { |x| x[1..-1] }

  included_tags & tags == included_tags and excluded_tags & tags == []
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
  alias :error   :red
  alias :failed  :red
  alias :warn    :yellow
  alias :ok      :green
  alias :info    :blue
  alias :debug   :grey
  alias :skipped :grey
end

module Spectre
  class CancelException < Exception
  end

  class SimpleReporter
    def initialize config
      @out = config['stdout'] || $stdout
    end

    def report runs
      errors   = runs.count { |x| !x.error.nil? }
      failed   = runs.count { |x| !x.failure.nil? }
      skipped  = runs.count { |x| x.skipped }
      succeded = runs.count - errors - failed - skipped

      summary  = "#{succeded} succeded"
      summary += " #{failed} failures"
      summary += " #{errors} errors"
      summary += " #{skipped} skipped"
      summary += "\n\n"

      output  = "\n"
      output += summary.send(errors + failed > 0 ? :red : :green)

      runs
        .select { |x| !x.error.nil? or !x.failure.nil? }
        .each_with_index do |run, index|
          title  = "#{index+1})"
          title += " #{run.parent.full_desc}"
          title += " (#{(run.finished - run.started).duration})"
          title += " [#{run.parent.name}]"

          output += title.red
          output += "\n"

          if run.error
            file, line = get_error_info(run.error)

            error_output  = "but an unexpected error occurred during run\n"
            error_output += "  file.....: #{file}:#{line}\n" if file
            error_output += "  type.....: #{run.error.class.name}\n"
            error_output += "  message..: #{run.error.message}\n"

            if CONFIG['debug'] and run.error.backtrace
              error_output += "  backtrace:\n"

              run.error.backtrace.each do |trace|
                error_output += "    #{trace}\n"
              end
            end

            output += error_output.indent(5).red
            output += "\n\n"
          end

          if run.failure
            output += "     #{run.failure.message.red}\n\n"
          end
        end

      @out.puts output
    end
  end

  class ConsoleFormatter
    def initialize
      @out = CONFIG['stdout'] || $stdout
      @level = 0
      @width = 80
      @indent = 2
    end

    def list specs
      colors = [:blue, :magenta, :yellow, :green]
      counter = 0

      specs
        .group_by { |x| x.parent.root }
        .each do |_context, spec_group|
          spec_group.each do |spec|
            spec_id = "[#{spec.name}]".send(colors[counter % colors.length])
            @out.puts "#{spec_id} #{spec.full_desc} #{spec.tags.map { |x| "##{x}" }.join(' ').cyan }"
          end

          counter += 1
        end
    end

    def details specs
      colors = [:blue, :magenta, :yellow, :green]
      counter = 0

      specs
        .group_by { |x| x.parent.root }
        .each do |_context, spec_group|
          spec_group.each do |spec|
            spec_id = "[#{spec.name}]".send(colors[counter % colors.length])
            spec_detail  = "#{spec_id}\n"
            spec_detail += "  subject..: #{spec.parent.desc}\n"
            spec_detail += "  desc.....: #{spec.desc}\n"
            spec_detail += "  tags.....: #{spec.tags.join(', ')}\n" if spec.tags.any?
            spec_detail += "  data.....: #{spec.data.to_json}\n" if spec.data
            spec_detail += "  file.....: #{spec.file}\n"

            @out.puts("#{spec_detail}\n")
          end

          counter += 1
        end
    end

    def scope desc, _subject, type
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
        @out.puts "\n"
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

    def log level, message, status=nil, desc=nil
      return if @locked

      write(message, true) if block_given? or @debug or level != :debug

      if block_given?
        @locked = true
        level, status, desc = yield
        @locked = false
      end

      label = status || level

      return unless block_given? or @debug or level != :debug

      status_text = "[#{label}]"

      if desc.nil?
        @out.puts status_text.send(label)
      else
        @out.puts "#{status_text} - #{desc}".send(label)
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
        @out.print output
      else
        message.lines.each do |line|
          output = indent + line
          @out.print output
        end
      end

      @out.print '.' * (@width > output.length ? @width - output.length : 0) if fill
    end
  end

  class JsonReporter
    def initialize
      @out = CONFIG['stdout'] || $stdout
      @out.sync = true
    end

    def report runs
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

      @out.puts reports.to_json
    end
  end

  class JsonFormatter
    def initialize
      @scope = nil
      @out = CONFIG['stdout'] || $stdout
      @out.sync = true
    end

    def list specs
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
              file: spec.file,
            }
          end,
        }
      end

      @out.puts specs
        .group_by { |x| x.parent.root }
        .map { |x| context_to_hash.call(x.first) }.to_json
    end

    def scope desc, _subject, type
      prev_scope = @scope
      @scope = SecureRandom.hex(5)

      log_entry = {
        id: @scope,
        scope: prev_scope,
        type: type,
        desc: desc,
      }

      @out.puts log_entry.to_json

      yield

      @scope = prev_scope
    end

    def log level, message, status=nil, desc=nil
      timestamp = DateTime.now
      log_id = SecureRandom.hex(5)

      write_log(log_id, timestamp, level, message, status, desc)

      level, status, desc = yield if block_given?

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

      @out.puts log_entry.to_json
    end
  end

  class RunContext
    attr_reader :id, :name, :parent, :type, :logs, :bag, :error, :failure, :skipped, :started, :finished

    @@current = nil

    def self.current
      @@current
    end

    def initialize parent, type, bag=nil
      @id = SecureRandom.hex(5)

      @parent = parent
      @type = type
      @logs = []

      @bag = OpenStruct.new(bag)

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
      Spectre.formatter.log(:debug, "expect #{desc}") do
        result = [:debug, :ok, nil]

        begin
          yield
        rescue Expectation::ExpectationFailure => e
          fail_message = "expected #{desc}, but it failed with \"#{e.message}\""
          @failure = Expectation::ExpectationFailure.new(fail_message)
          result = [:error, :failed, nil, @failure]
          Spectre.logger.error(fail_message)
        rescue Interrupt
          @skipped = true
          result = [:debug, :skipped, 'canceled by user']
          Spectre.logger.info("expecting #{desc} - canceled by user")
        rescue Exception => e
          @error = e
          result = [:fatal, :error, e.class.name, e]
          Spectre.logger.fatal("#{e.message}\n#{e.backtrace.join("\n")}")
        end

        result
      end

      raise CancelException if @skipped or @error or @failure
    end

    def group desc
      Spectre.formatter.scope(desc, @parent, :group) do
        yield
      end
    end

    def add_log timestamp, severity, progname, message
      @logs << [timestamp, severity, progname, message]
    end

    def observe desc
      Spectre.formatter.log(:info, "observe #{desc}".cyan) do
        begin
          yield
          @success = true
          [:info, :ok, nil]
        rescue Expectation::ExpectationFailure => e
          @success = false
          Spectre.logger.debug(e.message)
          [:warn, :warn, e.message]
        rescue => e
          @success = false
          Spectre.logger.debug("#{e.message}\n#{e.backtrace.join("\n")}")
          [:info, :ok, e.message]
        end
      end
    end

    def success?
      @success
    end

    def run desc, with: nil
      Spectre.formatter.scope(desc, self, :mixin) do
        with ||= [OpenStruct.new]
        with = [with.to_recursive_struct] if with.is_a? Hash
        with = with.map { |x| x.is_a?(Hash) ? x.to_recursive_struct : x }

        raise "mixin '#{desc}' not found" unless MIXINS.key? desc

        result = instance_exec(*with, &MIXINS[desc])

        result.is_a?(Hash) ? OpenStruct.new(result) : result
      end
    end

    alias :also :run

    def execute(data, &)
      begin
        instance_exec(data.is_a?(Hash) ? OpenStruct.new(data) : data, &)
      rescue CancelException
        # Do nothing. The run will be ended here
      rescue Expectation::ExpectationFailure => e
        @failure = e
        Spectre.formatter.log(:error, e.message, :failed, e.desc)
        file, line = get_error_info(e)
        Spectre.logger.error("#{e.message} - in #{file}:#{line}")
      rescue Interrupt
        @skipped = true
        Spectre.formatter.log(:debug, nil, :skipped, 'canceled by user')
        Spectre.logger.info("#{@parent.desc} - canceled by user")
      rescue Exception => e
        Spectre.formatter.log(:fatal, e.message, :error, e.class.name)
        @error = e
        Spectre.logger.fatal("#{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end

  class Specification
    attr_reader :id, :name, :desc, :parent, :root, :tags, :data, :file

    def initialize parent, name, desc, tags, data, file, block
      @id = SecureRandom.hex(5)
      @parent = parent
      @root = parent.root
      @name = name
      @desc = desc
      @tags = tags
      @data = data
      @file = file
      @block = block
    end

    def full_desc
      @parent.full_desc + ' ' + @desc
    end

    def run befores, afters, bag
      RunContext.new(self, :spec, bag) do |run_context|
        Spectre.formatter.scope(@desc, self, :spec) do
          begin
            if befores.any?
              Spectre.formatter.scope('before', self, :before) do
                befores.each do |block|
                  run_context.execute(@data, &block)
                end
              end
            end
            
            if run_context.error.nil? and run_context.failure.nil?
              run_context.execute(@data, &@block)
            end
          ensure
            if afters.any?
              Spectre.formatter.scope('after', self, :after) do
                afters.each do |block|
                  run_context.execute(@data, &block)
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

    def full_name
      return @name unless @parent

      @parent.full_name + '-' + @name
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
      file = caller
        .first
        .gsub(/:in .*/, '')
        .gsub(Dir.getwd, '.')

      with = with || [nil]

      with.each_with_index do |data, _index|
        spec_index = @specs.count + 1
        name = "#{full_name}-#{spec_index}"

        spec = Specification.new(self, name, desc, tags, data, file, block)

        @specs << spec
      end
    end

    def run specs
      selected = @specs.select { |x| specs.include? x }
      runs = []

      if selected.any?
        Spectre.formatter.scope(@desc, self, :context) do
          setup_run = nil
          setup_bag = nil

          if @setups.any?
            setup_run = RunContext.new(self, :setup) do |run_context|
              Spectre.formatter.scope('setup', self, :setup) do
                @setups.each do |block|
                  run_context.execute(nil, &block)
                end
              end
            end

            setup_bag = setup_run.bag

            runs << setup_run
          end

          # Only run specs if setup was successful
          if setup_run.nil? or (setup_run.error.nil? and setup_run.failure.nil?)
            runs += selected.map do |spec|
              spec.run(@befores, @afters, setup_bag)
            end
          end

          if @teardowns.any?
            runs << RunContext.new(self, :teardown, setup_bag) do |run_context|
              Spectre.formatter.scope('teardown', self, :teardown) do
                @teardowns.each do |block|
                  run_context.execute(nil, &block)
                end
              end
            end
          end
        end
      end

      @children.each do |context|
        runs += context.run(specs)
      end

      runs
    end
  end

  # Define default config

  CONFIG = {
    'config_file' => './spectre.yml',
    # 'log_file'             => './logs/spectre_<date>.log',
    'log_file' => StringIO.new,
    'log_date_format' => '%Y-%m-%d %H:%M:%S.%3N',
    'log_message_format' => "[%s] %5s -- [%s] %s: %s\n",
    'formatter' => 'Spectre::ConsoleFormatter',
    'reporter' => 'Spectre::SimpleReporter',
    'specs' => [],
    'tags' => [],
    'debug' => false,
    'env_patterns' => ['environments/**/*.env.yml'],
    'env_partial_patterns' => ['environments/**/*.env.secret.yml'],
    'spec_patterns' => ['specs/**/*.spec.rb'],
    'mixin_patterns' => ['mixins/**/*.mixin.rb'],
    'resource_paths' => ['../common/resources', './resources'],
    'modules' => [],
  }

  CONTEXTS = []
  MIXINS = {}
  RESOURCES = {}
  ENVIRONMENTS = {}

  DEFAULT_ENV_NAME = 'default'

  class << self
    attr_reader :env, :formatter, :logger

    def setup config_overrides
      # Load global config file
      global_config_file = File.join(File.expand_path('~'), '.spectre')

      if File.exist? global_config_file
        global_config = load_yaml(global_config_file)
        CONFIG.deep_merge!(global_config)
      end

      # Load main spectre config
      main_config_file = config_overrides['config_file'] || CONFIG['config_file']

      if File.exist? main_config_file
        main_config = load_yaml(main_config_file)
        CONFIG.deep_merge!(main_config)
        Dir.chdir(File.dirname(main_config_file))
      end

      # Load environments
      CONFIG['env_patterns'].each do |pattern|
        Dir.glob(pattern).each do |file_path|
          loaded_env = load_yaml(file_path)
          env_name = loaded_env['name'] || DEFAULT_ENV_NAME
          ENVIRONMENTS[env_name] = loaded_env
        end
      end

      # Load and merge partial environment files
      CONFIG['env_partial_patterns'].each do |pattern|
        Dir.glob(pattern).each do |file_path|
          loaded_env = load_yaml(file_path)
          env_name = loaded_env['name'] || DEFAULT_ENV_NAME
          ENVIRONMENTS[env_name].deep_merge!(loaded_env) if ENVIRONMENTS.key?(env_name)
        end
      end

      # Select environment and merge it
      CONFIG.deep_merge!(ENVIRONMENTS[CONFIG.delete('selected_env') || DEFAULT_ENV_NAME])

      # Merge property overrides
      CONFIG.deep_merge!(config_overrides)

      # Set env before loading specs in order to make it available in spec definitions
      @env = CONFIG.to_recursive_struct.freeze

      # Load specs
      # Note that spec files are only loaded once, because of the relative require,
      # even if the setup function is called multiple times
      require_files(CONFIG['spec_patterns'])
      CONTEXTS.freeze

      # Load mixins
      # Mixins are also only loaded once
      require_files(CONFIG['mixin_patterns'])
      MIXINS.freeze

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

      @formatter = Object.const_get(CONFIG['formatter']).new

      self
    end

    def init_logger
      log_file = CONFIG['log_file']

      if log_file.is_a? String
        log_file = log_file.gsub('<date>', DateTime.now.strftime('%Y-%m-%d_%H%M%S%3N'))
        FileUtils.mkdir_p(File.dirname(log_file))
      end

      @logger = Logger.new(log_file)
      @logger.formatter = proc do |severity, datetime, progname, message|
        date_fromatted = datetime.strftime(CONFIG['log_date_format'])
        progname = progname || 'spectre'

        # Add log message also to the current executing run context
        unless RunContext.current.nil?
          RunContext.current.add_log(date_fromatted, severity, progname, message)
          context_name = RunContext.current.parent.name
        else
          context_name = 'spectre'
        end

        CONFIG['log_message_format'] % [date_fromatted, severity, context_name, progname, message]
      end

      self
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
      init_logger()

      list
        .group_by { |x| x.parent.root }
        .map do |context, specs|
          context.run(specs)
        end
        .flatten
    end

    def report runs
      Object.const_get(CONFIG['reporter'])
        .new(CONFIG)
        .report(runs)
    end

    def describe(name, &)
      main_context = CONTEXTS.find { |x| x.desc == name }

      if main_context.nil?
        main_context = DefinitionContext.new(name)
        CONTEXTS << main_context
      end

      main_context.instance_eval(&)
    end

    def mixin desc, &block
      MIXINS[desc] = block
    end

    def resources
      RESOURCES
    end

    %i{debug info warn}.each do |method|
      define_method(method) do |message|
        Spectre.logger.send(method, message)
        Spectre.formatter.log(method, message)
      end
    end

    private

    def require_files patterns
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
