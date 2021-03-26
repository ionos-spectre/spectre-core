module Spectre
  module Version
    MAJOR = 1
    MINOR = 6
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'


  ###########################################
  # Custom Exceptions
  ###########################################


  class ExpectationFailure < Exception
    attr_reader :expectation

    def initialize expectation, message
      super message
      @expectation = expectation
    end
  end


  ###########################################
  # Internal Classes
  ###########################################


  # https://www.dan-manges.com/blog/ruby-dsls-instance-eval-with-delegation
  class DslClass
    def _evaluate &block
      @__bound_self__ = eval 'self', block.binding
      instance_eval(&block)
    end

    def _execute args, &block
      @__bound_self__ = eval 'self', block.binding
      instance_exec(args, &block)
    end

    def method_missing method, *args, &block
      if @__bound_self__.respond_to? method
        @__bound_self__.send method, *args, &block
      else
        Delegator.redirect method, *args, &block
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

    def add_spec desc, tags, data, block, context
      name = @name + '-' + (@specs.length+1).to_s
      @specs << Spec.new(name, self, desc, tags, data, block, context)
    end
  end


  class Spec
    attr_reader :name, :subject, :context, :desc, :tags, :data, :block

    def initialize name, subject, desc, tags, data, block, context
      @name = name
      @context = context
      @data = data
      @subject = subject
      @desc = desc
      @tags = tags
      @block = block
    end

    def full_desc
      @subject.desc + ' ' + desc
    end
  end


  class RunInfo
    attr_reader :spec, :data, :error, :started, :finished

    def initialize spec, data
      @spec = spec
      @data = data
      @started = nil
      @finished = nil
      @error = nil
      @skipped = false
    end

    def duration
      @finished - @started
    end

    def skipped?
      @skipped
    end

    def failed?
      @error != nil
    end

    def record ctx
      @started = Time.now

      begin
        if @spec.context.__before_blocks.count > 0
          before_ctx = SpecContext.new @spec.subject, 'before'
          Logger.log_context before_ctx do
            @spec.context.__before_blocks.each do |block|
              ctx._execute(@data, &block)
            end
          end
        end

        ctx._execute(@data, &@spec.block)

      rescue ExpectationFailure => e
        @error = e

      rescue Interrupt
        @skipped = true
        Logger.log_skipped @spec

      rescue Exception => e
        @error = e
        Logger.log_error @spec, e

      ensure
        if @spec.context.__after_blocks.count > 0
          before_ctx = SpecContext.new @spec.subject, 'after'
          Logger.log_context before_ctx do
            @spec.context.__after_blocks.each do |block|
              ctx._execute(@data, &block)
            end
          end
        end
      end

      @finished = Time.now
    end
  end


  class Runner
    def run specs
      runs = []

      specs.group_by { |x| x.subject }.each do |subject, spec_group|
        Logger.log_subject subject do
          spec_group.group_by { |x| x.context }.each do |context, specs|
            Logger.log_context(context) do
              runs.concat run_context(context, specs)
            end
          end
        end
      end

      runs
    end

    private

    def run_context context, specs
      runs = []

      setup_ctx = RunContext.new

      if context.__setup_blocks.count > 0
        before_ctx = SpecContext.new context, 'setup'
        Logger.log_context before_ctx do
          context.__setup_blocks.each do |block|
            setup_ctx._evaluate &block
          end
        end
      end

      begin
        specs.each do |spec|
          if spec.data.length > 0
            spec.data.each do |data|
              Logger.log_spec(spec, data) do
                runs << run_spec(spec, data)
              end
            end
          else
            Logger.log_spec(spec) do
              runs << run_spec(spec)
            end
          end
        end
      ensure
        if context.__teardown_blocks.count > 0
          before_ctx = SpecContext.new context, 'teardown'
          Logger.log_context before_ctx do
            context.__teardown_blocks.each do |block|
              setup_ctx._evaluate &block
            end
          end
        end
      end

      runs
    end

    def run_spec spec, data=nil
      run_ctx = RunContext.new
      run_info = RunInfo.new(spec, data)
      run_info.record(run_ctx)
      run_info
    end
  end


  ###########################################
  # DSL Classes
  ###########################################


  class SpecContext < DslClass
    attr_reader :__subject, :__desc, :__before_blocks, :__after_blocks, :__setup_blocks, :__teardown_blocks

    def initialize subject, desc=nil
      @__subject = subject
      @__desc = desc

      @__before_blocks = []
      @__after_blocks = []
      @__setup_blocks = []
      @__teardown_blocks = []
    end

    def it desc, tags: [], with: [], &block
      @__subject.add_spec(desc, tags, with, block, self)
    end

    def before &block
      @__before_blocks << block
    end

    def after &block
      @__after_blocks << block
    end

    def setup &block
      @__setup_blocks << block
    end

    def teardown &block
      @__teardown_blocks << block
    end

    def context desc=nil, &block
      ctx = SpecContext.new(@__subject, desc)
      ctx._evaluate &block
    end
  end


  class RunContext < DslClass
    def skip
      raise Interrupt
    end
  end


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

    def self.redirect method_name, *args, &block
      target = @@mappings[method_name]
      raise "no method or variable '#{method_name}' defined" if !target
      target.send(method_name, *args, &block)
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
          (spec_filter.empty? or spec_filter.any? { |x| spec.name.match('^' + x.gsub('*', '.*') + '$') }) and (tags.empty? or tags.any? { |x| has_tag(spec.tags, x) })
        end
    end


    def has_tag tags, tag_exp
      tags = tags.map { |x| x.to_s }
      all_tags = tag_exp.split '+'
      included_tags = all_tags.select { |x| !x.start_with? '!' }
      excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
      included_tags & tags == included_tags and excluded_tags & tags == []
    end


    def delegate *method_names, to: nil
      Spectre::Delegator.delegate *method_names, to
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

      if !subject
        subject = Subject.new(desc)
        @@subjects << subject
      end

      ctx = SpecContext.new(subject)
      ctx._evaluate &block
    end

  end

  delegate :describe, to: Spectre
end


extend Spectre::Delegator