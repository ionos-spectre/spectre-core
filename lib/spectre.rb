# frozen_string_literal: true

require 'ostruct'
require 'yaml'
require 'json'
require 'optparse'
require 'ectoplasm'
require 'date'
require 'fileutils'
require 'securerandom'
require 'logger'
require 'stringio'

require_relative 'spectre/version'

class Hash
  # :nodoc:
  def deep_merge!(second)
    return unless second.is_a?(Hash)

    merger = proc { |_key, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge!(v2, &merger) : v2 }
    merge!(second, &merger)
  end

  # :nodoc:
  def to_recursive_struct
    OpenStruct.new(
      transform_values do |val|
        val.is_a?(Hash) ? val.to_recursive_struct : val
      end
    )
  end
end

class String
  alias error   red
  alias failed  red
  alias warn    yellow
  alias ok      green
  alias info    blue
  alias debug   grey
  alias skipped grey
end

module Spectre
  class AbortException < StandardError
  end

  class Failure < StandardError
    # A message describing the failure
    attr_reader :message
    # The file path where the failure occured
    attr_reader :file
    # The line where the failure occured
    attr_reader :line

    ##
    # Constructs a new +Failure+ instance with the given message
    # and determines the +file+ and +line+ from the given call stack
    def initialize message, call_stack = nil
      super(message)

      loc = (call_stack || caller_locations)
        .select { |x| ['<main>', '<top (required)>'].include? x.base_label }
        .first

      @message = message
      @file = loc.absolute_path.sub(Dir.pwd, '.')
      @line = loc.lineno
    end

    # :nodoc:
    def to_s
      "#{@message} - in #{@file}:#{@line}"
    end
  end

  class EvaluationContext
    attr_reader :desc, :failures

    def initialize(desc, &)
      @desc = desc
      @failures = []

      Spectre.formatter.log(:info, desc) do
        instance_eval(&)

        if @failures.any?
          Spectre.logger.error("#{desc} - failed")
          [:error, :failed, nil]
        else
          Spectre.logger.info("#{desc} - ok")
          [:info, :ok, nil]
        end
      rescue Failure => e
        report(e)
        [:error, :failed, nil]
      end
    end

    def report failure
      @failures << failure
    end

    def failure desc
      Failure.new(desc, caller_locations)
    end
  end

  class Logger < ::Logger
    def initialize config
      log_file = config['log_file']

      if log_file.is_a? String
        log_file = log_file.gsub('<date>', DateTime.now.strftime('%Y-%m-%d_%H%M%S%3N'))
        FileUtils.mkdir_p(File.dirname(log_file))
      end

      super(log_file)

      @corr_ids = []

      @formatter = proc do |severity, datetime, progname, message|
        date_formatted = datetime.strftime(config['log_date_format'])
        progname ||= 'spectre'

        corr_id = @corr_ids.join

        # Add log message also to the current executing run context
        if RunContext.current.nil?
          context_name = 'spectre'
        else
          RunContext.current.logs << [date_formatted, severity, progname, corr_id, message]
          context_name = RunContext.current.name
        end

        format(config['log_message_format'],
               date_formatted,
               severity,
               progname,
               context_name,
               corr_id,
               message)
      end
    end

    def correlate
      @corr_ids.append(rand(36**4).to_s(36))

      begin
        yield
      ensure
        @corr_ids.pop
      end
    end
  end

  class SimpleReporter
    def initialize config
      @out = config['stdout'] || $stdout
      @debug = config['debug']
    end

    def report runs
      runs = runs.select { |x| x.parent.is_a? Specification }

      errors    = runs.count { |x| x.status == :error }
      failed    = runs.count { |x| x.status == :failed }
      skipped   = runs.count { |x| x.status == :skipped }
      succeeded = runs.count - errors - failed - skipped

      summary  = "#{succeeded} succeeded"
      summary += " #{failed} failures"
      summary += " #{errors} errors"
      summary += " #{skipped} skipped"

      @out.puts(summary.send((errors + failed).positive? ? :red : :green))

      output = "\n"

      runs
        .select { |x| [:error, :failed].include? x.status }
        .each_with_index do |run, index|
          index += 1

          output += "#{index})"
          output += " #{run.parent.full_desc}"
          output += " (#{(run.finished - run.started).duration})"
          output += " [#{run.parent.name}]"

          output += "\n"

          if run.error
            location = run.error
              .backtrace_locations
              .select { |x| x.base_label == '<top (required)>' }
              .first

            file = location.absolute_path.sub(Dir.pwd, '.')
            line = location.lineno

            error_output  = "but an unexpected error occurred during run\n"
            error_output += "  file.....: #{file}:#{line}\n" if file
            error_output += "  type.....: #{run.error.class.name}\n"
            error_output += "  message..: #{run.error.message}\n"

            if @debug and run.error.backtrace
              error_output += "  backtrace:\n"

              run.error.backtrace.each do |trace|
                error_output += "    #{trace}\n"
              end
            end

            output += error_output.indent(5)
            output += "\n\n"
          end

          next unless run.status == :failed

          failed = run.evaluations
            .select { |x| x.failures.any? }

          failed.each_with_index do |eval, eval_idx|
            output += if failed.count == 1
                        "     #{eval.desc}, but"
                      else
                        "     #{index}.#{eval_idx + 1}) #{eval.desc}, but"
                      end

            if eval.failures.count == 1
              output += " #{eval.failures.first.message}\n"
            else
              output += " #{eval.failures.count} failures occured\n"

              eval.failures.each_with_index do |fail, fail_idx|
                output += if failed.count == 1
                            "       #{index}.#{fail_idx + 1}) #{fail.message}\n"
                          else
                            "       #{index}.#{eval_idx + 1}.#{fail_idx + 1}) #{fail.message}\n"
                          end
              end
            end
          end

          output += "\n"
        end

      @out.puts output.red
    end
  end

  class SimpleFormatter
    def initialize config
      @out = config['stdout'] || $stdout
      @level = 0
      @width = 80
      @indent = 2
      @colors = [:blue, :magenta, :yellow, :green]
    end

    def list specs
      counter = 0

      specs
        .group_by { |x| x.parent.root }
        .each_value do |spec_group|
          spec_group.each do |spec|
            spec_id = "[#{spec.name}]".send(@colors[counter % @colors.length])
            @out.puts "#{spec_id} #{spec.full_desc} #{spec.tags.map { |x| "##{x}" }.join(' ').cyan}"
          end

          counter += 1
        end
    end

    def details specs
      counter = 0

      specs
        .group_by { |x| x.parent.root }
        .each_value do |spec_group|
          spec_group.each do |spec|
            spec_id = "[#{spec.name}]".send(@colors[counter % @colors.length])
            spec_detail  = "#{spec_id}\n"
            spec_detail += "  subject..: #{spec.root.desc}\n"
            spec_detail += "  context..: #{spec.parent.desc}\n" unless spec.root == spec.parent
            spec_detail += "  desc.....: #{spec.desc}\n"
            spec_detail += "  tags.....: #{spec.tags.join(', ')}\n" if spec.tags.any?
            spec_detail += "  data.....: #{spec.data.to_json}\n" if spec.data
            spec_detail += "  file.....: #{spec.file}\n"

            @out.puts("#{spec_detail}\n")
          end

          counter += 1
        end
    end

    def scope desc, type
      if desc
        colored_desc = case type
                       when :before, :after, :setup, :teardown
                         desc.magenta
                       when :group
                         desc.grey
                       when :spec
                         desc.cyan
                       when :mixin
                         desc.yellow
                       when :context
                         desc.blue
                       else
                         desc
                       end

        write(colored_desc)

        @out.puts "\n"
      end

      return unless block_given?

      @level += 1

      begin
        yield
      ensure
        @level -= 1
      end
    end

    def log level, message, status = nil, desc = nil
      return if @locked

      write(message, fill: true) if block_given? or @debug or level != :debug

      error = nil

      if block_given?
        @locked = true

        begin
          level, status, desc = yield
        rescue StandardError => e
          level = :fatal
          status = :error
          desc = e.class
          error = e
        ensure
          @locked = false
        end
      end

      label = status || level

      return unless block_given? or @debug or level != :debug

      status_text = "[#{label}]"

      if desc.nil?
        @out.puts status_text.send(label)
      else
        @out.puts "#{status_text} - #{desc}".send(label)
      end

      raise error if error
    end

    private

    def indent
      ' ' * (@level * @indent)
    end

    def write message, fill: false
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

  class RunContext
    attr_reader :id, :name, :parent, :type, :logs, :bag, :error,
                :evaluations, :started, :finished, :properties

    @@current = nil
    @@location_cache = {}

    def self.current
      @@current
    end

    def initialize parent, type, bag = nil
      @id = SecureRandom.hex(5)

      @parent = parent
      @type = type
      @logs = []

      @name = parent.name
      @name += "-#{type}" unless type == :spec

      @bag = OpenStruct.new(bag)

      @properties = {}

      @evaluations = []
      @error = nil
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

    def execute(data, &)
      instance_exec(data.is_a?(Hash) ? OpenStruct.new(data) : data, &)
    rescue AbortException
      # Do nothing. The run will be ended here
    rescue Interrupt
      @skipped = true
      Spectre.formatter.log(:debug, nil, :skipped, 'canceled by user')
      Spectre.logger.info("#{@parent.desc} - canceled by user")
    rescue StandardError => e
      @error = e
      Spectre.formatter.log(:fatal, e.message, :error, e.class.name)
      Spectre.logger.fatal("#{e.message}\n#{e.backtrace.join("\n")}")
    end

    def status
      return :error if @error
      return :failed if @evaluations.any? { |x| x.failures.any? }
      return :skipped if @skipped

      :success
    end

    %i[assert expect].each do |method|
      define_method(method) do |evaluation, &block|
        desc = "#{method} #{evaluation}"

        @evaluations << if block
                          EvaluationContext.new(desc, &block)
                        else
                          EvaluationContext.new(desc) do
                            unless evaluation.failure.nil?
                              report(Failure.new(
                                       evaluation.failure,
                                       evaluation.call_location
                                     ))
                            end
                          end
                        end

        raise AbortException if method == :assert
      end
    end

    def property **kwargs
      @properties.merge!(kwargs)
    end

    def duration
      @finished - @started
    end

    def group(desc, &)
      Spectre.logger.correlate do
        Spectre.logger.debug("group \"#{desc}\"")
        Spectre.formatter.scope(desc, :group, &)
      end
    end

    def observe desc
      Spectre.formatter.log(:info, "observe #{desc}".cyan) do
        yield
        @success = true
        [:info, :ok, nil]
      rescue StandardError => e
        @success = false
        Spectre.logger.debug("#{e.message}\n#{e.backtrace.join("\n")}")
        [:info, :warn, e.message]
      end
    end

    # Returns the status of the `observe` execution
    def success?
      @success.nil? ? true : @success
    end

    # Method to run mixins
    def run desc, with: nil
      Spectre.formatter.scope(desc, :mixin) do
        with ||= [OpenStruct.new]
        with = [with.to_recursive_struct] if with.is_a? Hash
        with = with.map { |x| x.is_a?(Hash) ? x.to_recursive_struct : x }

        raise "mixin \"#{desc}\" not found" unless MIXINS.key? desc

        Spectre.logger.correlate do
          Spectre.logger.debug("execute mixin \"#{desc}\"")
          result = instance_exec(*with, &MIXINS[desc])
          return result.is_a?(Hash) ? OpenStruct.new(result) : result
        end
      end
    end

    # Add this alias to construct prettier mixin execution calls
    alias also run

    def skip message
      @skipped = true
      Spectre.logger.info("#{message} - canceled by user")
      raise AbortException
    end
  end

  class Specification
    attr_reader :id, :name, :desc, :full_desc, :parent, :root, :tags, :data, :file

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
      @full_desc = "#{@parent.full_desc} #{@desc}"
    end

    def run befores, afters, bag
      RunContext.new(self, :spec, bag) do |run_context|
        Spectre.formatter.scope(@desc, :spec) do
          befores.each do |block|
            Spectre.formatter.scope('before', :before) do
              Spectre.logger.correlate do
                run_context.execute(@data, &block)
              end
            end
          end

          run_context.execute(@data, &@block) if run_context.status == :success
        ensure
          afters.each do |block|
            Spectre.formatter.scope('after', :after) do
              Spectre.logger.correlate do
                run_context.execute(@data, &block)
              end
            end
          end
        end
      end
    end
  end

  class DefinitionContext
    attr_reader :id, :name, :desc, :parent, :full_desc, :children, :specs

    def initialize desc, parent = nil
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
      @name = @parent.name + '-' + @name unless @parent.nil?

      @full_desc = @parent.nil? ? @desc : "#{@parent.full_desc} #{@desc}"
    end

    def root
      @parent ? @parent.root : self
    end

    def all_specs
      @specs + @children.map(&:all_specs).flatten
    end

    def context(desc, &)
      context = DefinitionContext.new(desc, self)
      @children << context
      context.instance_eval(&)
    end

    ##
    # Adds a setup block which will be executed
    # once at the beginning of a context.
    # Multiple setups are allowed.
    #
    def setup &block
      @setups << block
    end

    ##
    # Adds a teardown block which will be executed
    # once at the end of a context.
    # Multiple teardowns are allowed.
    #
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

      with ||= [nil]

      with.each_with_index do |data, _index|
        spec_index = root.all_specs.count + 1
        name = "#{root.name}-#{spec_index}"

        spec = Specification.new(self, name, desc, tags, data, file, block)

        @specs << spec
      end
    end

    def run specs
      selected = @specs.select { |x| specs.include? x }
      runs = []

      if selected.any?
        Spectre.formatter.scope(@desc, :context) do
          setup_bag = nil

          if @setups.any?
            setup_run = RunContext.new(self, :setup) do |run_context|
              @setups.each do |block|
                Spectre.formatter.scope('setup', :setup) do
                  Spectre.logger.correlate do
                    Spectre.logger.debug("setup \"#{@desc}\"")
                    run_context.execute(nil, &block)
                  end
                end
              end
            end

            setup_bag = setup_run.bag

            runs << setup_run
          end

          # Only run specs if setup was successful
          if runs.all? { |x| x.status == :success }
            runs += selected.map do |spec|
              Spectre.logger.correlate do
                spec.run(@befores, @afters, setup_bag)
              end
            end
          end

          if @teardowns.any?
            runs << RunContext.new(self, :teardown, setup_bag) do |run_context|
              @teardowns.each do |block|
                Spectre.formatter.scope('teardown', :teardown) do
                  Spectre.logger.correlate do
                    Spectre.logger.debug("teardown \"#{@desc}\"")
                    run_context.execute(nil, &block)
                  end
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

  ##
  # Define default config
  # This `Hash` can be manipulated before calling `Spectre.setup`
  # However config overrides should be done by passing `config_overrides` to `Spectre.setup`
  #
  CONFIG = {
    'work_dir' => '.',
    'global_config_file' => '~/.config/spectre.yml',
    'config_file' => 'spectre.yml',
    # 'log_file' => './logs/spectre_<date>.log',
    'log_file' => StringIO.new,
    'log_date_format' => '%F %T.%L%:z',
    # [timestamp] LEVEL -- module_name: [spec-id] correlation_id log_message
    'log_message_format' => "[%s] %5s -- %s: [%s] [%s] %s\n",
    'formatter' => 'Spectre::SimpleFormatter',
    'reporter' => 'Spectre::SimpleReporter',
    'out_path' => 'reports',
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

  ##
  # Contains all `Spectre::DefinitionContext`s added by `Spectre.describe`
  #
  CONTEXTS = []
  MIXINS = {}
  RESOURCES = {}
  ENVIRONMENTS = {}

  DEFAULT_ENV_NAME = 'default'

  class << self
    attr_reader :env, :formatter, :logger

    ##
    # Setup spectre with given config
    # Has to be called before any spec run
    #
    def setup config_overrides
      # Load global config file
      global_config_file = config_overrides['global_config_file'] || File.expand_path('~/.config/spectre.yml')

      if File.exist? global_config_file
        global_config = load_yaml(global_config_file)
        CONFIG.deep_merge!(global_config)
      end

      # Set working directory so all paths in config
      # are relative to this directory
      Dir.chdir(config_overrides['work_dir'] || CONFIG['work_dir'] || '.')

      # Load main spectre config
      main_config_file = config_overrides['config_file'] || CONFIG['config_file']

      unless main_config_file.nil? or !File.exist? main_config_file
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

      # Load mixins
      # Mixins are also only loaded once
      require_files(CONFIG['mixin_patterns'])

      # Load resources
      CONFIG['resource_paths'].each do |resource_path|
        resource_files = Dir.glob File.join(resource_path, '**/*')

        resource_files.each do |file|
          file.slice! resource_path
          file = file[1..]
          RESOURCES[file] = File.expand_path File.join(resource_path, file)
        end
      end

      # Load modules
      if CONFIG['modules'].is_a? Array
        CONFIG['modules'].each do |module_name|
          module_path = File.join(Dir.pwd, module_name)

          if File.exist? module_path
            require_relative module_path
          else
            require module_name
          end
        end
      end

      @formatter = Object.const_get(CONFIG['formatter']).new(CONFIG)

      # If log file is an actual file path do not initilize the logger yet
      # as it will create the file immediatly, even the specs are just listed
      # Initialize it for testing purposes
      @logger = Logger.new(CONFIG) unless CONFIG['log_file'].is_a? String

      self
    end

    def list
      spec_filter = CONFIG['specs']
      tag_filter = CONFIG['tags']

      CONTEXTS
        .map(&:all_specs)
        .flatten
        .select do |spec|
          (spec_filter.empty? and tag_filter.empty?) or
            (spec_filter.empty? or spec_filter.any? { |x| spec.name.match?("^#{x.gsub('*', '.*')}$") }) and
            (tag_filter.empty? or tag_filter.any? { |x| tag?(spec.tags, x) })
        end
    end

    def run
      @logger = Logger.new(CONFIG)

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

    %i[debug info warn log].each do |method|
      define_method(method) do |message|
        message = message.to_s
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

    def tag? tags, tag_exp
      tags = tags.map(&:to_s)
      all_tags = tag_exp.split('+')

      included_tags = all_tags.reject { |x| x.start_with? '!' }

      excluded_tags = all_tags
        .select { |x| x.start_with? '!' }
        .map { |x| x[1..] }

      included_tags & tags == included_tags and excluded_tags & tags == []
    end
  end
end
