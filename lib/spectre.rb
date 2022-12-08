require 'ostruct'
require 'date'

module Spectre
  module Version
    MAJOR = 2
    MINOR = 0
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'


  class ::Hash
    def deep_merge!(second)
      merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge!(v2, &merger) : v2 }
      self.merge!(second, &merger)
    end

    def deep_merge(second)
      self.deep_clone.deep_merge!(second.deep_clone)
    end

    def deep_freeze
      self
        .map { |key, val| [key, val.deep_freeze] }
        .to_h
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

  class ::Array
    def deep_freeze
      self.map { |x| x.deep_freeze }
    end
  end

  class ::Object
    def to_h
      self.instance_variables.each_with_object({}) do |var, hash|
        hash[var.to_s.delete("@")] = self.instance_variable_get(var)
      end
    end

    def deep_freeze
      self.freeze
    end

    def deep_clone
      Marshal.load(Marshal.dump(self))
    end
  end


  ###########################################
  # Custom Exceptions
  ###########################################


  class SpectreError < Exception
  end

  class ExpectationFailure < Exception
    attr_reader :expectation

    def initialize message, expectation
      super message
      @expectation = expectation
    end
  end

  class SpectreSkip < Interrupt
  end

  ###########################################
  # Internal Classes
  ###########################################


  # https://www.dan-manges.com/blog/ruby-dsls-instance-eval-with-delegation
  class DslClass
    def _evaluate &block
      @__bound_self__ = eval('self', block.binding)
      instance_eval(&block)
    end

    def _execute *args, &block
      @__bound_self__ = eval('self', block.binding)
      instance_exec(*args, &block)
    end

    def method_missing method, *args, **kwargs, &block
      if @__bound_self__.respond_to? method
        @__bound_self__.send(method, *args, **kwargs, &block)
      else
        Delegator.redirect(method, *args, **kwargs, &block)
      end
    end
  end

  class Subject
    attr_reader :name, :desc, :specs

    def initialize desc
      @desc = desc
      @specs = []
      @name = desc.downcase.gsub(/[^a-z0-9]+/, '_')
    end

    def add_spec desc, tags, data, block, context, file, line
      name = @name + '-' + (@specs.length+1).to_s
      @specs << Spec.new(name, self, desc, tags, data, block, context, file, line)
    end

    def to_h
      {
        name: @name,
        desc: @desc,
        specs: @specs.map { |x| x.to_h }
      }
    end
  end

  class Spec
    attr_reader :id, :name, :subject, :context, :desc, :tags, :data, :block, :file, :line

    def initialize name, subject, desc, tags, data, block, context, file, line
      @name = name
      @context = context
      @data = data
      @subject = subject
      @desc = desc
      @tags = tags
      @block = block
      @file = file
      @line = line
    end

    def full_desc
      @subject.desc + ' ' + desc
    end

    def to_h
      {
        name: @name,
        context: @context.__desc,
        data: @data.map { |x| x.to_h },
        subject: @subject.desc,
        desc: @desc,
        tags: @tags,
        file: @file,
        line: @line,
      }
    end
  end

  class RunInfo
    attr_accessor :spec, :data, :started, :finished, :error, :failure, :skipped
    attr_reader :expectations, :log, :properties

    def initialize spec, data=nil
      @spec = spec
      @data = data
      @started = nil
      @finished = nil
      @error = nil
      @failure = nil
      @skipped = false
      @log = []
      @expectations = []
      @properties = {}
    end

    def duration
      @finished - @started
    end

    def skipped?
      @skipped
    end

    def failed?
      @failure != nil
    end

    def error?
      @error != nil
    end

    def success?
      @error == nil && @failure == nil
    end

    def status
      return :queued unless @started
      return :running if @started and not @finished
      return :error if error?
      return :failed if failed?
      return :skipped if skipped?

      return :success
    end

    def to_h
      date_format = '%FT%T.%L%:z'

      {
        spec: @spec.name,
        data: @data,
        started: @started.nil? ? nil : @started.strftime(date_format),
        finished: @finished.nil? ? nil : @finished.strftime(date_format),
        error: @error,
        failure: @failure,
        skipped: @skipped,
        status: status,
        log: @log.map { |timestamp, message, level| [timestamp.strftime(date_format), message, level] },
        expectations: @expectations,
        properties: @properties,
      }
    end
  end

  module Runner
    class << self
      def current
        Environment.bucket(:spectre_run)
      end

      def current= run
        Environment.put(:spectre_run, run)
      end

      def run specs
        runs = []

        specs.group_by { |x| x.subject }.each do |subject, subject_specs|
          Spectre::Eventing.trigger(:start_subject, subject)

          subject_specs.group_by { |x| x.context }.each do |context, context_specs|
            Spectre::Eventing.trigger(:start_context, context)
            runs.concat run_context(context, context_specs)
            Spectre::Eventing.trigger(:end_context, context)
          end

          Spectre::Eventing.trigger(:end_subject, subject)
        end

        runs
      end

      private

      def run_context context, specs
        runs = []

        context.__setup_blocks.each do |setup_spec|
          setup_run = run_setup(setup_spec, :setup)
          runs << setup_run
          return runs unless setup_run.success?
        end

        begin
          specs.each do |spec|
            raise SpectreError.new("Multi data definition (`with' parameter) of '#{spec.subject.desc} #{spec.desc}' has to be an `Array'") unless !spec.data.nil? and spec.data.is_a? Array

            if spec.data.any?
              spec.data
                .map { |x| x.is_a?(Hash) ? OpenStruct.new(x) : x }
                .each do |data|
                  runs << run_spec(spec, data)
                end
            else
              runs << run_spec(spec)
            end
          end
        ensure
          context.__teardown_blocks.each do |teardown_spec|
            runs << run_setup(teardown_spec, :teardown)
          end
        end

        runs
      end

      def run_setup spec, type
        run_info = RunInfo.new(spec)

        Runner.current = run_info

        run_info.started = Time.now

        Eventing.trigger(('start_' + type.to_s).to_sym, run_info)

        begin
          spec.block.call()

          run_info.finished = Time.now
        rescue ExpectationFailure => e
          run_info.failure = e
        rescue Exception => e
          run_info.error = e
          raise e
          Eventing.trigger(:spec_error, run_info, e)
        end

        run_info.finished = Time.now

        Eventing.trigger(('end_' + type.to_s).to_sym, run_info)

        Runner.current = nil

        run_info
      end

      def run_spec spec, data=nil
        run_info = RunInfo.new(spec, data)

        Runner.current = run_info

        run_info.started = Time.now

        Eventing.trigger(:start_spec, run_info)

        begin
          if spec.context.__before_blocks.count > 0
            Eventing.trigger(:start_before, run_info)

            spec.context.__before_blocks.each do |block|
              block.call(data)
            end

            Eventing.trigger(:end_before, run_info)
          end

          spec.block.call(data)
        rescue ExpectationFailure => e
          run_info.failure = e
          Logging.log("expected #{e.expectation}, but it failed with: #{e.message}", :error)
        rescue SpectreSkip => e
          run_info.skipped = true
          Eventing.trigger(:spec_skip, run_info, e.message)
        rescue Interrupt
          run_info.skipped = true
          Eventing.trigger(:spec_skip, run_info, 'canceled by user')
        rescue Exception => e
          run_info.error = e
          raise e
          Eventing.trigger(:spec_error, run_info, e)
          Logging.log(e.message, :error)
        ensure
          if spec.context.__after_blocks.count > 0
            Eventing.trigger(:start_after, run_info)

            begin
              spec.context.__after_blocks.each do |block|
                block.call
              end

              run_info.finished = Time.now
            rescue ExpectationFailure => e
              run_info.failure = e
            rescue Exception => e
              run_info.error = e
              raise e
              Eventing.trigger(:spec_error, run_info, e)
              Logging.log(e.message, :error)
            end

            Eventing.trigger(:end_after, run_info)
          end
        end

        run_info.finished = Time.now

        Eventing.trigger(:end_spec, run_info)

        Runner.current = nil

        run_info
      end
    end
  end


  ###########################################
  # DSL Classes
  ###########################################


  class SpecContext < DslClass
    attr_reader :__subject, :__desc, :__parent, :__before_blocks, :__after_blocks, :__setup_blocks, :__teardown_blocks

    def initialize subject, desc=nil, parent=nil
      @__subject = subject
      @__desc = desc
      @__parent = parent

      @__before_blocks = []
      @__after_blocks = []
      @__setup_blocks = []
      @__teardown_blocks = []
    end

    def it desc, tags: [], with: [], &block
      spec_file, line = get_call_location()

      @__subject.add_spec(desc, tags, with, block, self, spec_file, line)
    end

    def before &block
      @__before_blocks << block
    end

    def after &block
      @__after_blocks << block
    end

    def setup &block
      name = "#{@__subject.name}-setup-#{@__setup_blocks.count+1}"
      spec_file, line = get_call_location()

      setup_ctx = SpecContext.new(@__subject, 'setup', self)
      @__setup_blocks << Spec.new(name, @__subject, 'setup', [], nil, block, setup_ctx, spec_file, line)
    end

    def teardown &block
      name = "#{@__subject.name}-teardown-#{@__teardown_blocks.count+1}"
      spec_file, line = get_call_location()

      teardown_ctx = SpecContext.new(@__subject, 'teardown', self)
      @__teardown_blocks << Spec.new(name, @__subject, 'teardown', [], nil, block, teardown_ctx, spec_file, line)
    end

    def context desc=nil, &block
      ctx = SpecContext.new(@__subject, desc, self)
      ctx._evaluate &block
    end

    private

    def get_call_location
      path_and_line = caller[1].split(':')
      line = path_and_line[-2].to_i
      file = path_and_line[0..-3].join(':')
      [file, line]
    end
  end


  ###########################################
  # Core Modules
  ###########################################


  module Delegator
    @@mappings = {}

    def self.delegate(*methods, target)
      methods.each do |method_name|
        define_method(method_name) do |*args, &block|
          return super(*args, &block) if respond_to? method_name

          target.send(method_name, *args, &block)
        end

        @@mappings[method_name] = target

        private method_name
      end
    end

    def self.redirect method_name, *args, **kwargs, &block
      target = @@mappings[method_name] || Kernel
      raise SpectreError.new("no variable or method '#{method_name}' found") unless target.respond_to? method_name

      target.send(method_name, *args, **kwargs, &block)
    end
  end

  module Logging
    class ModuleLogger
      def initialize name
        @name = name
      end

      [:info, :debug, :warn, :error].each do |level|
        define_method(level) do |message|
          Spectre::Logging.log(message, level, @name)
        end
      end
    end

    class << self
      @@handlers = []

      def log message, level, name=nil
        log_entry = [DateTime.now, message, level, name]

        @@handlers.each do |handler|
          handler.send(:log, *log_entry) if handler.respond_to? :log
        end

        return unless Spectre::Runner.current
        Spectre::Runner.current.log << log_entry
      end

      def register module_logger
        @@handlers << module_logger
      end

      def configure config
        @@debug = config['debug']

        @@handlers.each do |handler|
          handler.configure(config) if handler.respond_to? :configure
        end
      end
    end
  end

  module Eventing
    class << self
      @@handlers = []

      def trigger event, *args
        @@handlers.each do |handler|
          handler.send(event, *args) if handler.respond_to? event
        end
      end

      def register handler
        @@handlers << handler
      end

      [:info, :debug, :warn, :error].each do |level|
        define_method(level) do |message|
          trigger(:log, message, level)
          Spectre::Runner.current.log << [DateTime.now, message, level, nil]
        end
      end

      alias :log :info
    end
  end

  module Environment
    def self.env
      bucket(:spectre_env)
    end

    def self.bucket name
      Thread.current[name] || (Thread.current[:parent].nil? ? nil : Thread.current[:parent][name])
    end

    def self.put name, val
      Thread.current[name] = val
    end

    def self.delete name
      Thread.current[name] = nil
    end

    def self.is_defined? name
      not Thread.current[name].nil?
    end
  end

  class << self
    @@subjects = []
    @@modules = []

    def subjects
      @@subjects
    end

    def specs spec_filter=[], tags=[]
      @@subjects
        .map { |x| x.specs }
        .flatten
        .select do |spec|
          (spec_filter.empty? or spec_filter.any? { |x| spec.name.match('^' + x.gsub('*', '.*') + '$') }) and (tags.empty? or tags.any? { |x| tag?(spec.tags, x) })
        end
    end

    def tag? tags, tag_exp
      tags = tags.map { |x| x.to_s }
      all_tags = tag_exp.split('+')
      included_tags = all_tags.select { |x| !x.start_with? '!' }
      excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
      included_tags & tags == included_tags and excluded_tags & tags == []
    end

    def delegate *method_names, to: nil
      Spectre::Delegator.delegate(*method_names, to)
    end

    def register mod
      @@modules << mod
    end

    def configure config
      Environment.put(:spectre_env, config.to_recursive_struct.freeze)

      Logging.configure(config)

      @@modules.each do |mod|
        mod.configure(config) if mod.respond_to? :configure
      end
    end

    def purge
      @@subjects = []
      @@modules = []
    end


    ###########################################
    # Global Functions
    ###########################################

    def describe desc, &block
      subject = @@subjects.find { |x| x.desc == desc }

      unless subject
        subject = Subject.new(desc)
        @@subjects << subject
      end

      ctx = SpecContext.new(subject)
      ctx._evaluate &block
    end

    def property key, val
      Spectre::Runner.current.properties[key] = val
    end

    def group desc
      Spectre::Eventing.trigger(:start_group, desc)
      yield
      Spectre::Eventing.trigger(:end_group, desc)
    end

    def skip message=nil
      raise SpectreSkip.new(message)
    end

    def bag
      Environment.put(:spectre_bag, OpenStruct.new) unless Environment.is_defined?(:spectre_bag)
      Environment.bucket(:spectre_bag)
    end
  end

  delegate(:describe, :property, :group, :skip, :bag, to: self)
  delegate(:log, :info, :debug, to: Eventing)
  delegate(:env, to: Environment)
end


extend Spectre::Delegator
