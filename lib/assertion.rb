require 'ostruct'

module Spectre
  module Assertion
    class ValueWrapper
      def self.wrap val
        val.is_a?(ValueWrapper) ? val : ValueWrapper.new(val)
      end

      def initialize val
        @val = val
      end

      def evaluate predicate, actual, negate
        !(!negate ^ predicate.call(@val, actual))
      end

      def to_s
        return "\"#{@val}\"" if @val.is_a?(String)
        return @val.inspect if @val.is_a?(Regexp)

        @val.to_s
      end
    end

    class OrWrapper < ValueWrapper
      def initialize first, second
        super(first)
        @first = ValueWrapper.wrap(first)
        @second = ValueWrapper.wrap(second)
      end

      def evaluate predicate, actual, negate
        @first.evaluate(predicate, actual, negate) or @second.evaluate(predicate, actual, negate)
      end

      def to_s
        "#{@first} or #{@second}"
      end
    end

    class AndWrapper < ValueWrapper
      def initialize first, second
        super(first)
        @first = ValueWrapper.wrap(first)
        @second = ValueWrapper.wrap(second)
      end

      def evaluate predicate, actual, negate
        @first.evaluate(predicate, actual, negate) and @second.evaluate(predicate, actual, negate)
      end

      def to_s
        "#{@first} and #{@second}"
      end
    end

    class Evaluation
      attr_reader :actual, :expected, :method, :negate

      def initialize actual, expected, method, predicate, negate: false
        @actual = actual
        @expected = ValueWrapper.wrap(expected)
        @predicate = predicate
        @negate = negate

        @repr = ''
        @repr += 'not ' if @negate
        @repr += "to #{method}"
        @repr += expected.nil? ? ' empty' : " #{@expected}"
      end

      def run
        @expected.evaluate(@predicate, @actual, @negate)
      end

      def to_s
        @repr
      end
    end

    class ::Object
      @@location_cache = {}

      def not params
        Evaluation.new(self, *params, negate: true)
      end

      def to params
        Evaluation.new(self, *params)
      end

      def or other_val
        OrWrapper.new(self, other_val)
      end

      def and other_val
        AndWrapper.new(self, other_val)
      end
    end

    class << self
      @@location_cache = {}

      def assert evaluation
        # Maybe not the most elegant way, but it works for now
        # as long as the `should` statement is on the same line as the variable
        loc = caller_locations
          .select { |x| ['<main>', '<top (required)>'].include? x.base_label }
          .first

        if @@location_cache.key?(loc.absolute_path)
          loc_file_content = @@location_cache[loc.absolute_path]
        else
          loc_file_content = File.read(loc.absolute_path)
          @@location_cache[loc.absolute_path] = loc_file_content
        end

        var_name = loc_file_content
          .lines[loc.lineno - 1]
          .strip
          .match(/assert\(?(.*)\.(to|not)/)
          .captures
          .first
          .strip

        EvaluationContext.new("assert #{var_name} #{evaluation}") do
          success = evaluation.run

          unless success
            message = "expected #{var_name} #{evaluation}, but got #{evaluation.actual.inspect}"
            report(message, loc)
          end
        end
      end

      def to params
        params
      end

      def be expected_val
        [
          expected_val,
          __method__,
          proc { |expected, actual| expected.inspect == actual.inspect },
        ]
      end

      def be_empty
        [
          nil,
          'be',
          proc { |_, actual| actual.nil? or (actual.respond_to?(:empty?) and actual.empty?) }
        ]
      end

      def contain expected_val
        [
          expected_val,
          __method__,
          proc { |expected, actual| actual.include?(expected) }
        ]
      end

      def match regex
        [
          regex,
          __method__,
          proc { |expected, actual| actual.match?(expected) }
        ]
      end
    end
  end
end
