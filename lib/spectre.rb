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

    def initialize subject, desc, parent: nil
      @subject = subject
      @desc = desc
      @before_blocks = []
      @after_blocks = []
      @setup_blocks = []
      @teardown_blocks = []
    end

    def it desc, tags: [], &block
      @subject.specs << Spec.new("#{@subject.name}-#{@subject.specs.length+1}", self, desc, tags, block)
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

    def context desc, &block
      ctx = SpecContext.new(desc, parent: self)
      ctx.instance_eval &block
    end
  end


  class Subject < SpecContext
    attr_reader :name, :specs

    def initialize desc
      super(desc)
      @specs = []
      @name = desc.downcase.gsub(/[^a-z0-9]+/, '_')
    end
  end


  class Spec
    attr_reader :name, :subject, :desc, :tags, :block
    attr_accessor :error

    def initialize name, subject, desc, tags, block
      @name = name
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
    attr_reader :subject, :spec

    def initialize subject, spec
      @subject = subject
      @spec = spec
      @started = nil
      @finished = nil
    end

    def duration
      @finished - @started
    end

    def start
      @started = Time.now
    end

    def end
      @finished = Time.now
    end
  end


  class Runner
    def initialize subjects, logger
      @subjects = subjects
      @logger = logger
    end

    def run spec_list, tags
      runs = []

      @subjects.each do |subject|
        specs = subject.specs.select do |spec|
          (spec_list.empty? or spec_list.include? spec.name) and (tags.empty? or tags.any? { |x| spec.tags.include? x.to_sym })
        end

        next if specs.length == 0

        @logger.log_subject(subject)

        setup_ctx = RunContext.new(@logger)

        begin
          subject.setup_blocks.each do |block|
            setup_ctx.instance_eval &block
          end

          specs.each do |spec|
            @logger.log_spec(spec)

            run_ctx = RunContext.new(@logger)
            run_info = RunInfo.new(subject, spec)
            run_info.start

            begin
              subject.before_blocks.each do |block|
                run_ctx.instance_eval &block
              end

              run_ctx.instance_eval &spec.block

            rescue ExpectationFailure => e
              spec.error = e

            rescue Exception => e
              spec.error = e

              if !e.cause
                @logger.log_error(e)
              end
            ensure
              subject.after_blocks.each do |block|
                run_ctx.instance_eval &block
              end

              run_info.end

              runs << run_info
            end
          end
        ensure
          subject.teardown_blocks.each do |block|
            setup_ctx.instance_eval &block
          end
        end
      end

      runs
    end
  end


  class << self
    @@subjects = []
    @@configs = []

    def subjects
      @@subjects
    end


    def delegate *module_names, to: nil
      module_names.each do |method_name|
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

      subject.instance_eval &block
    end

  end

  delegate :describe, to: Spectre
end
