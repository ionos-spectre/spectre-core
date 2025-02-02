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
      attr_reader :actual, :expected, :method, :negate, :desc, :failure, :call_location

      def initialize call_location, actual, expected, method, predicate, negate: false
        @call_location = call_location
        @actual = actual
        @expected = ValueWrapper.wrap(expected)
        @predicate = predicate
        @negate = negate
        @failure = nil

        # Maybe not the most elegant way, but it works for now
        # as long as the `.to` call is on the same line as the variable
        location = call_location
          .select { |x| ['<main>', '<top (required)>'].include? x.base_label }
          .first

        if @@location_cache.key?(location.absolute_path)
          file_content = @@location_cache[location.absolute_path]
        else
          file_content = File.read(location.absolute_path)
          @@location_cache[location.absolute_path] = file_content
        end

        @var_name = file_content
          .lines
          .slice(location.lineno - 2, 2)
          .map(&:strip)
          .join
          .match(/[\s\(]([^\s]+|\[.*\]|{.*})\.(to|not)[\s\(]/)
          .captures
          .first
          .strip

        @repr = @var_name
        @repr += ' not' if @negate
        @repr += " to #{method}"
        @repr += expected.nil? ? ' empty' : " #{@expected}"

        success = @expected.evaluate(@predicate, @actual, @negate)

        return if success

        @failure = if @negate
                     'it does not'
                   else
                     "got #{@actual.inspect}"
                   end
      end

      def to_s
        @repr
      end
    end

    class ::Object
      @@location_cache = {}

      def not params
        Evaluation.new(caller_locations, self, *params, negate: true)
      end

      def to params
        Evaluation.new(caller_locations, self, *params)
      end

      def or other_val
        OrWrapper.new(self, other_val)
      end

      def and other_val
        AndWrapper.new(self, other_val)
      end
    end

    class << self
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
