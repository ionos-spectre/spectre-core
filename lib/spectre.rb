module Spectre
  module Version
    MAJOR = 1
    MINOR = 4
    TINY  = 1
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

    def it desc, tags: [], with: [], &block
      @subject.add_spec(desc, tags, with, block, self)
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
        raise ExpectationFailure.new(desc, e.message), cause: nil

      rescue Exception => e
        @logger.log_status(Logger::Status::ERROR)
        raise ExpectationFailure.new(desc, e.message), cause: e

      end
    end

    def skip
      raise Interrupt
    end

    def log message
      @logger.log_info(message)
    end

    def fail_with message
      raise ExpectationFailure.new(nil, message)
    end
  end


  class RunInfo
    attr_reader :spec, :data, :error

    def initialize spec, data, logger
      @spec = spec
      @data = data
      @started = nil
      @finished = nil
      @logger = logger
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
        @spec.context.before_blocks.each do |block|
          ctx.instance_exec(@data, &block)
        end

        ctx.instance_exec(@data, &@spec.block)

      rescue ExpectationFailure => e
        @error = e

      rescue Interrupt
        @skipped = true
        @logger.log_skipped

      rescue Exception => e
        @error = e
        @logger.log_error(e)

      ensure
        @spec.context.after_blocks.each do |block|
          ctx.instance_exec(@data, &block)
        end
      end

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

      setup_ctx = RunContext.new(@logger)

      context.setup_blocks.each do |block|
        setup_ctx.instance_eval &block
        setup_ctx.freeze
      end

      begin
        specs.each do |spec|
          if spec.data.length > 0
            spec.data.each do |data|
              @logger.log_spec(spec, data) do
                runs << run_spec(spec, data)
              end
            end
          else
            @logger.log_spec(spec) do
              runs << run_spec(spec)
            end
          end
        end
      ensure
        context.teardown_blocks.each do |block|
          setup_ctx.instance_eval &block
        end
      end

      runs
    end

    def run_spec spec, data=nil
      run_ctx = RunContext.new(@logger)
      run_info = RunInfo.new(spec, data, @logger)
      run_info.record(run_ctx)
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
