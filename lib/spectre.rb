module Spectre
  module Version
    MAJOR = 0
    MINOR = 1
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'


  ###########################################
  # Custom Exceptions
  ###########################################


  class ExpectationFailure < Exception
    attr_reader :expectation, :failure

    def initialize expectation, failure
      @expectation = expectation
      @failure = failure
    end
  end


  ###########################################
  # Internal Classes
  ###########################################


  class SpecContext
    attr_reader :subject, :desc, :before_blocks, :after_blocks, :setup_blocks, :teardown_blocks

    def initialize subject, desc=nil
      @subject = subject
      @desc = desc

      @before_blocks = []
      @after_blocks = []
      @setup_blocks = []
      @teardown_blocks = []
    end

    def it desc, tags: [], &block
      @subject.add_spec(desc, tags, block, self)
    end

    def before &block
      @before_blocks << block
    end

    def after &block
      @after_blocks << block
    end

    def setup &block
      @setup_blocks << block
    end

    def teardown &block
      @teardown_blocks << block
    end

    def context desc=nil, &block
      ctx = SpecContext.new(@subject, desc)
      ctx.instance_eval &block
    end
  end


  class Subject
    attr_reader :name, :desc, :specs

    def initialize desc
      @desc = desc
      @specs = []
      @name = desc.downcase.gsub(/[^a-z0-9]+/, '_')
    end

    def add_spec desc, tags, block, context
      name = @name + '-' + (@specs.length+1).to_s
      @specs << Spec.new(name, self, desc, tags, block, context)
    end
  end


  class Spec
    attr_reader :name, :subject, :context, :desc, :tags, :block
    attr_accessor :error

    def initialize name, subject, desc, tags, block, context
      @name = name
      @context = context
      @subject = subject
      @desc = desc
      @tags = tags
      @block = block
      @error = nil
    end
  end


  class RunContext
    def initialize logger
      @logger = logger
    end

    def expect desc
      begin
        @logger.log_expect(desc)
        yield
        @logger.log_status(Logger::Status::OK)

      rescue ExpectationFailure => e
        @logger.log_status(Logger::Status::FAILED)
        raise desc, cause: e

      rescue Exception => e
        @logger.log_status(Logger::Status::ERROR)
        raise desc, cause: e

      end
    end

    def log message
      @logger.log_info(message)
    end

    def fail_with message
      raise ExpectationFailure.new(nil, message)
    end
  end


  class RunInfo
    attr_reader :spec

    def initialize spec
      @spec = spec
      @started = nil
      @finished = nil
    end

    def duration
      @finished - @started
    end

    def record
      @started = Time.now
      yield
      @finished = Time.now
    end
  end


  class Runner
    def initialize logger
      @logger = logger
    end

    def run specs
      runs = []

      specs.group_by { |x| x.subject }.each do |subject, spec_group|
        @logger.log_subject(subject)

        spec_group.group_by { |x| x.context }.each do |context, specs|
          @logger.log_context(context) do
            runs.concat run_context(context, specs)
          end
        end
      end

      runs
    end

    private

    def run_context context, specs
      runs = []

      ctx = RunContext.new(@logger)

      context.setup_blocks.each do |block|
        ctx.instance_eval &block
        ctx.freeze
      end

      begin
        specs.each do |spec|
          @logger.log_spec(spec) do
            runs << run_spec(spec)
          end
        end
      ensure
        context.teardown_blocks.each do |block|
          ctx.instance_eval &block
        end
      end

      runs
    end

    def run_spec spec
      run_ctx = RunContext.new(@logger)
      run_info = RunInfo.new(spec)

      run_info.record do
        begin
          spec.context.before_blocks.each do |block|
            run_ctx.instance_eval &block
          end

          run_ctx.instance_eval &spec.block

        rescue ExpectationFailure => e
          spec.error = e

        rescue Exception => e
          spec.error = e
          @logger.log_error(e) unless e.cause

        ensure
          spec.context.after_blocks.each do |block|
            run_ctx.instance_eval &block
          end
        end
      end

      run_info
    end
  end


  class << self
    @@subjects = []
    @@configs = []


    def specs spec_filter=[], tags=[]
      @@subjects
        .map { |x| x.specs }
        .flatten
        .select do |spec|
          (spec_filter.empty? or spec_filter.any? { |x| spec.name.match('^' + x.gsub('*', '.*') + '$') }) and (tags.empty? or tags.any? { |x| spec.tags.include? x.to_sym })
        end
    end


    def delegate *method_names, to: nil
      method_names.each do |method_name|
        Kernel.define_method(method_name) do |*args, &block|
          to.send(method_name, *args, &block)
        end
      end
    end


    def register &block
      @@configs << block
    end


    def configure config
      @@configs.each do |block|
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
      ctx.instance_eval &block
    end

  end

  delegate :describe, to: Spectre
end
