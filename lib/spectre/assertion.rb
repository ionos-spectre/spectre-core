require_relative '../spectre'
require_relative '../spectre/helpers'

require 'ostruct'
require_relative 'logger'


module Spectre
  module Assertion
    class ::Object
      def should_be(value)
        evaluate(value, "#{self} should be #{value}") do |x|
          self.equal? x
        end
      end

      def should_be_empty
        raise AssertionFailure.new("#{self.to_s.trim} should be empty", nil, self) unless self.nil?
      end

      def should_not_be(val)
        raise AssertionFailure.new("#{self.to_s.trim} should not be #{val.to_s.trim}", val, self) unless self.to_s != val.to_s
      end

      def should_not_exist
        raise AssertionFailure.new("#{self.to_s.trim} should not exist, but it does", val, self) unless self.to_s != nil
      end

      def should_not_be_empty
        raise AssertionFailure.new('empty value', 'nothing', self) unless self != nil
      end

      def evaluate val, message, &block
        val = Evaluation.new(val) unless val.is_a? Evaluation
        raise AssertionFailure.new(message, val, self) unless val.run &block
      end

      def or other
        OrEvaluation.new(self, other)
      end

      def and other
        AndEvaluation.new(self, other)
      end
    end

    class ::NilClass
      def should_be(val)
        raise AssertionFailure.new("Value is empty, but it should be '#{val.to_s.trim}'", val, nil) unless val == nil
      end

      def should_be_empty
      end

      def should_not_be(val)
        raise AssertionFailure.new(val, 'nil') unless val != nil
      end

      def should_not_exist
      end

      def should_not_be_empty
        raise AssertionFailure.new('Value is empty', 'nil')
      end
    end

    class ::Hash
      def should_contain(other)
        raise AssertionFailure.new(other, self) unless self.merge(other) == self
      end

      def should_not_contain(other)
        raise AssertionFailure.new(other, self) unless self.merge(other) != self
      end

      def should_be_empty
        raise AssertionFailure.new('Object should be empty', nil, self) unless self.empty?
      end

      def should_not_be_empty
        raise AssertionFailure.new('Object should not be empty', nil, self) if self.empty?
      end
    end

    class ::OpenStruct
      def should_be_empty
        raise AssertionFailure.new('Object should be empty', nil, self) unless self.to_h.empty?
      end

      def should_not_be_empty
        raise AssertionFailure.new('Object should not be empty', nil, self) if self.to_h.empty?
      end
    end

    class ::Array
      def should_contain(val)
        list = self

        if val.is_a? Hash and self.all? { |x| x.is_a? OpenStruct or x.is_a? Hash }
          list = self.map { |x| OpenStruct.new(x) }
          val = OpenStruct.new(val)
        end

        evaluate(val, "#{self} should contain #{val.to_s}") do |x|
          self.include? x
        end
      end

      def should_not_contain(val)
        list = self

        if val.is_a? Hash and self.all? { |x| x.is_a? OpenStruct or x.is_a? Hash }
          list = self.map { |x| OpenStruct.new(x) }
          val = OpenStruct.new(val)
        end

        raise AssertionFailure.new("[#{list.join(', ').trim}] should not contain '#{val.to_s.trim}'", val, list) if list.include? val
      end

      def should_be_empty
        raise AssertionFailure.new('List is not empty', self) unless self.empty?
      end

      def should_not_be_empty
        raise AssertionFailure.new('List is empty', self) if self.empty?
      end
    end

    class ::String
      def should_be(val)
        raise AssertionFailure.new("'#{self.trim}' should be '#{val.to_s.trim}'", val, self) unless self == val
      end

      def should_be_empty
        raise AssertionFailure.new("'#{self.trim}' should be empty", nil, self) unless self.empty?
      end

      def should_not_be(val)
        raise AssertionFailure.new("'#{self.trim}' should not be '#{val.to_s.trim}'", val, self) unless self != val
      end

      def should_not_be_empty
        raise AssertionFailure.new('Text should not be empty', 'nothing', self) unless not self.empty?
      end

      def should_contain(value)
        evaluate(value, "'#{self.trim}' should contain #{value.to_s}") do |x|
          self.include? x.to_s
        end
      end

      def should_not_contain(val)
        raise AssertionFailure.new("'#{self.trim}' should not contain '#{val.trim}'", val, self) if self.include? val
      end

      def should_match(regex)
        raise AssertionFailure.new("'#{self.trim}' should match '#{val}'", regex, self) unless self.match(regex)
      end

      def should_not_match(regex)
        raise AssertionFailure.new("'#{self.trim}' should not match '#{val}'", regex, self) if self.match(regex)
      end

      alias :| :or
      alias :& :and
    end

    class Evaluation
      def initialize val
        @val = val
      end

      def run &block
        evaluate(@val)
      end

      def evaluate(val, predicate)
        if val.is_a? Evaluation
          val.run &predicate
        else
          predicate.call(val)
        end
      end

      def to_s
        @val.to_s
      end
    end

    class OrEvaluation < Evaluation
      def initialize val, other
        @val = val
        @other = other
      end

      def run &block
        res1 = evaluate(@val, block)
        res2 = evaluate(@other, block)
        res1 or res2
      end

      def to_s
        "(#{@val} or #{@other})"
      end
    end

    class AndEvaluation < Evaluation
      def initialize val, other
        @val = val
        @other = other
      end

      def run &block
        res1 = evaluate(@val, block)
        res2 = evaluate(@other, block)
        res1 and res2
      end

      def to_s
        "(#{@val} and #{@other})"
      end
    end

    class AssertionFailure < ExpectationFailure
      attr_reader :expected, :actual

      def initialize message, expected=nil, actual=nil, expectation=nil
        super message, expectation
        @expected = expected
        @actual = actual
      end
    end


    class << self
      @@success = nil

      def expect desc
        status = 'unknown'

        begin
          Logging.log_process("expect #{desc}")
          yield
          Logging.log_status(desc, Logging::Status::OK)
          status = 'ok'
        rescue Interrupt => e
          status = 'skipped'
          raise e
        rescue AssertionFailure => e
          Logging.log_status(desc, Logging::Status::FAILED)
          status = 'failed'
          raise AssertionFailure.new(e.message, e.expected, e.actual, desc), cause: nil
        rescue Exception => e
          Logging.log_status(desc, Logging::Status::ERROR)
          status = 'error'
          raise AssertionFailure.new("An unexpected error occurred during expectation: #{e.message}", nil, nil, desc), cause: e
        ensure
          Spectre::Runner.current.expectations.append([desc, status])
        end
      end

      def observe desc = nil
        prefix = 'observing'
        prefix += " '#{desc}'" if desc

        begin
          Logging.log_info(prefix) if desc
          yield
          @@success = true
          @@logger.info("#{prefix} finished with success")
        rescue Interrupt => e
          raise e
        rescue Exception => e
          error_message = "#{prefix} finished with failure: #{e.message}"
          error_message += "\n" + e.backtrace.join("\n") if @@debug

          @@logger.info(error_message)
          @@success = false
        end
      end

      def success?
        @@success
      end

      def fail_with message
        raise AssertionFailure.new(message)
      end
    end

    Spectre.register do |config|
      @@logger = Spectre::Logging::ModuleLogger.new(config, 'spectre/assertion')
      @@debug = config['debug']
    end

    Spectre.delegate :expect, :observe, :success?, :fail_with, to: self
  end
end
