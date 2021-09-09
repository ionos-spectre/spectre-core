require 'ostruct'
require_relative 'logger'


module Spectre
  module Assertion
    class ::Object
      def should_be(val)
        raise AssertionFailure.new("The value '#{self.to_s.trim}' should be '#{val.to_s.trim}'", val, self) unless self.to_s == val.to_s
      end

      def should_be_empty
        raise AssertionFailure.new("The value '#{self.to_s.trim}' should be empty", nil, self) unless self.nil?
      end

      def should_not_be(val)
        raise AssertionFailure.new("The value '#{self.to_s.trim}' should not be '#{val.to_s.trim}'", val, self) unless self.to_s != val.to_s
      end

      def should_not_exist
        raise AssertionFailure.new("The value '#{self.to_s.trim}' should not exist, but it does", val, self) unless self.to_s != nil
      end

      def should_not_be_empty
        raise AssertionFailure.new('The value should not be empty', 'nothing', self) unless self != nil
      end

      def or other
        OrEvaluation.new self, other
      end

      def and other
        AndEvaluation.new self, other
      end
    end


    class ::NilClass
      def should_be(val)
        raise AssertionFailure.new("There is nothing, but the value should be '#{val.to_s.trim}'", val, nil) unless val == nil
      end

      def should_be_empty
      end

      def should_not_be(val)
        raise AssertionFailure.new(val, 'nil') unless val != nil
      end

      def should_not_exist
      end

      def should_not_be_empty
        raise AssertionFailure.new('not empty', 'nil')
      end
    end


    class ::Hash
      def should_contain(other)
        raise AssertionFailure.new(other, self) unless self.merge(other) == self
      end

      def should_not_contain(other)
        raise AssertionFailure.new(other, self) unless self.merge(other) != self
      end
    end


    class ::Array
      def should_contain(val)
        list = self

        if val.is_a? Hash and self.all? { |x| x.is_a? OpenStruct or x.is_a? Hash }
          list = self.map { |x| OpenStruct.new(x) }
          val = OpenStruct.new(val)
        end

        raise AssertionFailure.new("The list [#{list.join(', ').trim}] should contain '#{val.to_s.trim}'", val, list) unless list.include? val
      end

      def should_not_contain(val)
        list = self

        if val.is_a? Hash and self.all? { |x| x.is_a? OpenStruct or x.is_a? Hash }
          list = self.map { |x| OpenStruct.new(x) }
          val = OpenStruct.new(val)
        end

        raise AssertionFailure.new("The list [#{list.join(', ').trim}] should not contain '#{val.to_s.trim}'", val, list) if list.include? val
      end

      def should_be_empty
        raise AssertionFailure.new('empty list', self) unless self.empty?
      end

      def should_not_be_empty
        raise AssertionFailure.new('no empty list', self) if self.empty?
      end
    end


    class ::String
      def should_be(val)
        raise AssertionFailure.new("The text '#{self.trim}' should be '#{val.to_s.trim}'", val, self) unless self == val
      end

      def should_be_empty
        raise AssertionFailure.new("The text '#{self.trim}' should be empty", nil, self) unless self.empty?
      end

      def should_not_be(val)
        raise AssertionFailure.new("The text '#{self.trim}' should not be '#{val.to_s.trim}'", val, self) unless self != val
      end

      def should_not_be_empty
        raise AssertionFailure.new('The text should not be empty', 'nothing', self) unless not self.empty?
      end

      def should_contain(value)
        raise AssertionFailure.new("`value' must not be nil") if value.nil?

        predicate = proc { |x| self.include? x.to_s }
        evaluation = SingleEvaluation.new(value)
        success = evaluation.call(predicate)

        return if success

        raise AssertionFailure.new("The text '#{self.to_s.trim}' should contain #{evaluation.to_s}", evaluation, self)
      end

      def should_not_contain(val)
        raise AssertionFailure.new("The text '#{self.trim}' should not contain '#{val.trim}'", val, self) if self.include? val
      end

      def should_match(regex)
        raise AssertionFailure.new("The text '#{self.trim}' should match '#{val}'", regex, self) unless self.match(regex)
      end

      def should_not_match(regex)
        raise AssertionFailure.new("The text '#{self.trim}' should not match '#{val}'", regex, self) if self.match(regex)
      end

      alias :| :or
      alias :& :and
    end


    class Evaluation
      def initialize value, other
        @value = value
        @other = other
      end

      def eval_assertion predicate, val
        if val.is_a? Evaluation
          val.call(predicate)
        else
          predicate.call(val)
        end
      end

      alias :| :or
      alias :& :and
    end


    class SingleEvaluation < Evaluation
      def initialize value
        super(value, nil)
      end

      def call predicate
        eval_assertion(predicate, @value)
      end

      def to_s
        @value.to_s
      end
    end


    class OrEvaluation < Evaluation
      def initialize value, other
        super(value, other)
      end

      def call predicate
        eval_assertion(predicate, @value) or eval_assertion(predicate, @other)
      end

      def to_s
        "(#{@value.to_s} or #{@other.to_s})"
      end
    end


    class AndEvaluation < Evaluation
      def initialize value, other
        super(value, other)
      end

      def call predicate
        eval_assertion(predicate, @value) and eval_assertion(predicate, @other)
      end

      def to_s
        "(#{@value.to_s} and #{@other.to_s})"
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
        begin
          Logger.log_process("expect #{desc}")
          yield
          Logger.log_status(desc, Logger::Status::OK)

        rescue Interrupt => e
          raise e

        rescue AssertionFailure => e
          Logger.log_status(desc, Logger::Status::FAILED)
          raise AssertionFailure.new(e.message, e.expected, e.actual, desc), cause: nil

        rescue Exception => e
          Logger.log_status(desc, Logger::Status::ERROR)
          raise AssertionFailure.new("An unexpected error occured during expectation: #{e.message}", nil, nil, desc), cause: e
        end
      end

      def observe desc = nil
        begin
          Logger.log_info("observing #{desc}") if desc
          yield
          @@success = true

        rescue Interrupt => e
          raise e

        rescue Exception => e
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

    Spectre.delegate :expect, :observe, :success?, :fail_with, to: self
  end
end
