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
  def contains? other
    self.merge(other) == self
  end
end


class Array
  def should_contain(val)
    raise Spectre::ExpectationError.new(val, self) unless self.include? val
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


  class Run
    def expect desc
      begin
        print "    expect #{desc} " + ('.' * (50 - desc.length))
        yield
        print "[ok]\n".green
      
      rescue ExpectationError => e
        print "[failed - #{$err_count+1}]\n".red
        raise desc, cause: e

      rescue Exception => e
        print "[error - #{$err_count+1}]\n".red
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

  
  class << self

    def subjects
      @@subjects
    end

    def run specs, tags
      $err_count = 0

      @@subjects.each do |subject|
        puts "#{subject.desc.blue}"

        subject.specs.each do |spec|
          next unless specs.empty? or specs.include? spec.id
          next unless tags.empty? or tags.any? { |x| spec.tags.include? x.to_sym }

          puts "  #{spec.desc.cyan}"

          spec_run = Run.new

          subject.before_blocks.each do |before|
            spec_run.instance_eval &before
          end
        
          begin
            spec_run.instance_eval &spec.block

          rescue ExpectationError => e
            spec.error = e
            $err_count += 1
          
          rescue Exception => e
            spec.error = e
            
            if !e.cause
              puts '    ' + ('.' * 58) + "[error - #{$err_count+1}]".red
            end 
            
            $err_count += 1
          ensure
            subject.after_blocks.each do |after|
              spec_run.instance_eval &after
            end
          end
        end
      end

      @@subjects
    end


    def report subjects
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

      counter = 0
      errors = 0
      failures = 0

      subjects.each do |subject|
        subject.specs.each do |spec|
          next unless spec.error

          counter += 1
          report_str += "\n#{counter}) #{subject.desc} #{spec.desc} [#{spec.id}]\n"
        
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
      end

      if failures + errors > 0
        summary = ''
        summary += "#{failures} failures " if failures > 0
        summary += "#{errors} errors" if errors > 0
        puts "\n#{summary}".red
      else
        puts "Run finished successfully".green
      end

      puts report_str.red
    end


    # Global Functions


    def describe desc, &block
      subject = Subject.new(desc, block)
      subject.instance_eval &block
      @@subjects << subject
    end

  end
  
  
  # Function Exports
  
  
  [:describe].each do |method_name|
    Kernel.define_method(method_name) do |*args, &block|
      Spectre.send(method_name, *args, &block)
    end
  end

end
