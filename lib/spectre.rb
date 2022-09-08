module Spectre
  module Version
    MAJOR = 1
    MINOR = 14
    TINY  = 2
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'


  class ::Hash
    def deep_merge!(second)
      merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge!(v2, &merger) : v2 }
      self.merge!(second, &merger)
    end

    def deep_clone
      Marshal.load(Marshal.dump(self))
    end
  end

  class ::Object
    def to_h
      self.instance_variables.each_with_object({}) do |var, hash|
        hash[var.to_s.delete("@")] = self.instance_variable_get(var)
      end
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

    def add_spec desc, tags, data, block, context, file
      name = @name + '-' + (@specs.length+1).to_s
      @specs << Spec.new(name, self, desc, tags, data, block, context, file)
    end
  end

  class Spec
    attr_reader :name, :subject, :context, :desc, :tags, :data, :block, :file

    def initialize name, subject, desc, tags, data, block, context, file
      @name = name
      @context = context
      @data = data
      @subject = subject
      @desc = desc
      @tags = tags
      @block = block
      @file = file
    end

    def full_desc
      @subject.desc + ' ' + desc
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

    def status
      return :error if error?
      return :failed if failed?
      return :skipped if skipped?

      return :success
    end
  end

  class Runner
    @@current = nil

    def self.current
      @@current
    end

    def run specs
      runs = []

      specs.group_by { |x| x.subject }.each do |subject, subject_specs|
        Logging.log_subject subject do
          subject_specs.group_by { |x| x.context }.each do |context, context_specs|
            Logging.log_context(context) do
              runs.concat run_context(context, context_specs)
            end
          end
        end
      end

      runs
    end

    private

    def run_context context, specs
      runs = []

      context.__setup_blocks.each do |setup_spec|
        setup_run = run_setup(setup_spec)
        runs << setup_run
        return runs if setup_run.error or setup_run.failure
      end

      begin
        specs.each do |spec|
          raise SpectreError.new("Multi data definition (`with' parameter) of '#{spec.subject.desc} #{spec.desc}' has to be an `Array'") unless !spec.data.nil? and spec.data.is_a? Array

          if spec.data.any?
            spec.data
              .map { |x| x.is_a?(Hash) ? OpenStruct.new(x) : x }
              .each do |data|
                Logging.log_spec(spec, data) do
                  runs << run_spec(spec, data)
                end
              end
          else
            Logging.log_spec(spec) do
              runs << run_spec(spec)
            end
          end
        end
      ensure
        context.__teardown_blocks.each do |teardown_spec|
          runs << run_setup(teardown_spec)
        end
      end

      runs
    end

    def run_setup spec
      run_info = RunInfo.new(spec)

      @@current = run_info

      run_info.started = Time.now

      Logging.log_context(spec.context) do
        begin
          spec.block.call()

          run_info.finished = Time.now
        rescue ExpectationFailure => e
          run_info.failure = e
        rescue Exception => e
          run_info.error = e
          Logging.log_error(spec, e)
        end
      end

      run_info.finished = Time.now

      @@current = nil

      run_info
    end

    def run_spec spec, data=nil
      run_info = RunInfo.new(spec, data)

      @@current = run_info

      run_info.started = Time.now

      begin
        if spec.context.__before_blocks.count > 0
          before_ctx = SpecContext.new(spec.subject, 'before', spec.context)

          Logging.log_context before_ctx do
            spec.context.__before_blocks.each do |block|
              block.call(data)
            end
          end
        end

        spec.block.call(data)
      rescue ExpectationFailure => e
        run_info.failure = e
      rescue SpectreSkip => e
        run_info.skipped = true
        Logging.log_skipped(spec, e.message)
      rescue Interrupt
        run_info.skipped = true
        Logging.log_skipped(spec, 'canceled by user')
      rescue Exception => e
        run_info.error = e
        Logging.log_error(spec, e)
      ensure
        if spec.context.__after_blocks.count > 0
          after_ctx = SpecContext.new(spec.subject, 'after', spec.context)

          Logging.log_context after_ctx do
            begin
              spec.context.__after_blocks.each do |block|
                block.call
              end

              run_info.finished = Time.now
            rescue ExpectationFailure => e
              run_info.failure = e
            rescue Exception => e
              run_info.error = e
              Logging.log_error(spec, e)
            end
          end
        end
      end

      run_info.finished = Time.now

      @@current = nil

      run_info
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
      spec_file = get_file()

      @__subject.add_spec(desc, tags, with, block, self, spec_file)
    end

    def before &block
      @__before_blocks << block
    end

    def after &block
      @__after_blocks << block
    end

    def setup &block
      name = "#{@__subject.name}-setup"
      spec_file = get_file()

      setup_ctx = SpecContext.new(@__subject, 'setup', self)
      @__setup_blocks << Spec.new(name, @__subject, 'setup', [], nil, block, setup_ctx, spec_file)
    end

    def teardown &block
      name = "#{@__subject.name}-teardown"
      spec_file = get_file()

      teardown_ctx = SpecContext.new(@__subject, 'teardown', self)
      @__teardown_blocks << Spec.new(name, @__subject, 'teardown', [], nil, block, teardown_ctx, spec_file)
    end

    def context desc=nil, &block
      ctx = SpecContext.new(@__subject, desc, self)
      ctx._evaluate &block
    end

    private

    def get_file
      # Get the file, where the spec is defined.
      # Nasty, but it works
      # Maybe there is another way, but this works for now

      begin
        raise
      rescue => e
        return e.backtrace
          .select { |file| !file.include? 'lib/spectre' }
          .first
          .match(/(.*\.rb):\d+/)
          .captures
          .first
      end
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


  class << self
    @@subjects = []
    @@modules = []

    attr_reader :file_log, :logger


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

    def register &block
      @@modules << block
    end

    def configure config
      @@modules.each do |block|
        block.call(config)
      end
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

    def skip message=nil
      raise SpectreSkip.new(message)
    end
  end

  delegate :describe, :property, :skip, to: Spectre
end


extend Spectre::Delegator
