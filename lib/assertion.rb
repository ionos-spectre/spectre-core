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

      def evaluate matcher
        matcher.call(@val)
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

      def evaluate matcher
        @first.evaluate(matcher) or @second.evaluate(matcher)
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

      def evaluate matcher
        @first.evaluate(matcher) and @second.evaluate(matcher)
      end

      def to_s
        "#{@first} and #{@second}"
      end
    end

    class Matcher
      def initialize actual, expected, predicate, method
        @actual = actual
        @expected = ValueWrapper.wrap(expected)
        @predicate = predicate

        @repr = "to #{method.to_s.gsub('_', ' ')}"
        @repr += expected.nil? ? ' not set' : " #{@expected}"
      end

      def evaluate
        @expected.evaluate(@predicate, @expected)
      end

      def to_s
        @repr
      end
    end

    class ::Object
      @@location_cache = {}

      def not params
        Matcher.new(self, *params)
      end

      def to params
        Matcher.new(self, *params)
      end
    end

    class << self
      def be expected_val
        [
          __method__,
          expected_val,
          proc { |x| x.to_s == val.to_s },
        ]
      end

      def be_empty
        prox { |_| val.nil? or val.empty? }
      end

      def contain expected_val
        proc { |x| val.include?(x) }
      end

      def match regex
        proc { |_| val.match?(regex) }
      end
    end
  end
end
