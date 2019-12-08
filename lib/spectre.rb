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


  class Subject
    attr_reader :desc, :block, :specs, :before_blocks, :after_blocks
    def initialize desc, block
      @id = desc.downcase.gsub(/[^a-z0-9]+/, '_')
      @desc = desc
      @block = block
      @specs = []
      @before_blocks = []
      @after_blocks = []
    end

    def it desc, tags: [], &block
      @specs << Spec.new("#{@id}-#{@specs.length+1}", self, desc, tags, block)
    end

    def before &block
      @before_blocks << block
    end

    def after &block
      @after_blocks << block
    end
  end


  class Spec
    attr_reader :id, :subject, :desc, :tags, :block
    attr_accessor :error

    def initialize id, subject, desc, tags, block
      @id = id
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

    def run specs, tags
      runs = []

      @subjects.each do |subject|
        @logger.log_subject(subject)

        subject.specs.each do |spec|
          next unless specs.empty? or specs.include? spec.id
          next unless tags.empty? or tags.any? { |x| spec.tags.include? x.to_sym }

          @logger.log_spec(spec)

          run_ctx = RunContext.new(@logger)
          run_info = RunInfo.new(subject, spec)
          run_info.start

          subject.before_blocks.each do |before|
            run_ctx.instance_eval &before
          end
        
          begin
            run_ctx.instance_eval &spec.block

          rescue ExpectationFailure => e
            spec.error = e
          
          rescue Exception => e
            spec.error = e
            
            if !e.cause
              @logger.log_error(e)
            end 
          ensure
            subject.after_blocks.each do |after|
              run_ctx.instance_eval &after
            end

            run_info.end

            runs << run_info
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
        subject = Subject.new(desc, block)
        @@subjects << subject
      end

      subject.instance_eval &block
    end
    
  end
  
  delegate :describe, to: Spectre
end
