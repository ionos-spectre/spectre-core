# Extension Methods


class String
  @@colored = false

  def self.colored!
    @@colored = true
  end

  def white;   self; end
  def red; colored '31'; end
  def green; colored '32'; end
  def yellow; colored '33'; end
  def blue; colored '34'; end
  def magenta; colored '35'; end
  def cyan; colored '36'; end
  def grey; colored '90'; end

  private

  def colored ansi_color
    return self if !@@colored
    "\e[#{ansi_color}m#{self}\e[0m"
  end
end


class Object
  def should_be(val)
    raise Spectre::ExpectationError.new(val, self) unless self == val
  end

  def should_not_be(val)
    raise Spectre::ExpectationError.new(val, self) unless self != val
  end
end


class Hash
  def should_contain(other)
    raise Spectre::ExpectationError.new(other, self) unless self.merge(other) == self
  end
end


class Array
  def should_contain(val)
    raise Spectre::ExpectationError.new(val, self) unless self.include? val
  end
end


class String
  def as_json
    JSON.parse(self)
  end
end


module Spectre
  module Version
    MAJOR = 0
    MINOR = 1
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'
  
  # Module Variables
  
  
  @@subjects = []
  
  
  # Custom Exceptions
  
  
  class ExpectationError < Exception
    attr_reader :expectation, :failure

    def initialize expectation, failure
      @expectation = expectation
      @failure = failure
    end
  end


  # Internal Classes


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
    def expect desc
      begin
        print "    expect #{desc} " + ('.' * (50 - desc.length))
        yield
        print "[ok]\n".green
      
      rescue ExpectationError => e
        print "[failed]\n".red
        raise desc, cause: e

      rescue Exception => e
        print "[error] #{e.class.name}\n".red
        raise desc, cause: e
      
      end
    end

    def log message
      puts ("    #{message} " + ('.' * (57 - message.length)) + '[info]').grey
    end

    def fail_with message
      raise ExpectationError.new(nil, message)
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

  
  class << self

    def subjects
      @@subjects
    end

    def run specs, tags
      runs = []
      $err_count = 0

      @@subjects.each do |subject|
        puts "#{subject.desc.blue}"

        subject.specs.each do |spec|
          next unless specs.empty? or specs.include? spec.id
          next unless tags.empty? or tags.any? { |x| spec.tags.include? x.to_sym }

          puts "  #{spec.desc.cyan}"

          run_ctx = RunContext.new
          run_info = RunInfo.new(subject, spec)
          run_info.start

          subject.before_blocks.each do |before|
            run_ctx.instance_eval &before
          end
        
          begin
            run_ctx.instance_eval &spec.block

          rescue ExpectationError => e
            spec.error = e
          
          rescue Exception => e
            spec.error = e
            
            if !e.cause
              puts '    ' + ('.' * 58) + "[error] #{e.class.name}".red
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


    def report spec_runs
      def print_exception error
        file, line = error.backtrace[0].match(/(.*\.rb):(\d+)/).captures
        file.slice!(Dir.pwd + '/')
        str = ''
        str += "       file.....: #{file}\n"
        str += "       line.....: #{line}\n"
        str += "       type.....: #{error.class}\n"
        str += "       message..: #{error.message}\n"
        str
      end

      report_str = ''

      errors = 0
      failures = 0

      spec_runs
        .select { |x| x.spec.error }
        .each_with_index do |run_info, index|
        
        subject = run_info.subject
        spec = run_info.spec

        report_str += "\n#{index+1}) #{subject.desc} #{spec.desc} (#{'%.3f' % run_info.duration}s) [#{spec.id}]\n"
      
        if spec.error.cause
          report_str += "     expected #{spec.error}\n"
      
          if spec.error.cause.is_a? ExpectationError
            report_str += "     but it failed with #{spec.error.cause.failure}\n"
            failures += 1
          else
            report_str += "     but it failed with an unexpected error\n"
            report_str += print_exception(spec.error.cause)
            errors += 1
          end
      
        else
          report_str += "     but an unexpected error occured during run\n"
          report_str += print_exception(spec.error)
          errors += 1
        end
      end

      if failures + errors > 0
        summary = ''
        summary += "#{spec_runs.length - failures - errors} succeeded "
        summary += "#{failures} failures " if failures > 0
        summary += "#{errors} errors " if errors > 0
        summary += "#{spec_runs.length} total"
        puts "\n#{summary}".red
      else
        puts "Run finished successfully".green
      end

      puts report_str.red
    end


    def delegate *module_names, to: nil
      module_names.each do |method_name|
        Kernel.define_method(method_name) do |*args, &block|
          to.send(method_name, *args, &block)
        end
      end
    end


    # Global Functions


    def describe desc, &block
      subject = Subject.new(desc, block)
      subject.instance_eval &block
      @@subjects << subject
    end
    
  end
  
  delegate :describe, to: Spectre
end
