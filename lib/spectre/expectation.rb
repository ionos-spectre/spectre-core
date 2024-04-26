require 'ostruct'

module Spectre
  module Expectation
    class ExpectationFailure < StandardError
      attr_reader :desc

      def initialize message, desc = nil
        super(message)
        @desc = desc
      end
    end

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

    class MultiValue
      def initialize desc, &block
        @block = block
        @desc = desc
      end

      def evaluate matcher
        @block.call(matcher)
      end

      def to_s
        @desc
      end
    end

    class Matcher
      def initialize expected_val, method, &block
        @block = block
        @expected_val = ValueWrapper.wrap(expected_val)

        @repr = "to #{method.to_s.gsub('_', ' ')}"
        @repr += expected_val.nil? ? ' nil' : " #{@expected_val}"
      end

      def execute val, negate
        @block.call(val, negate, @expected_val)
      end

      def to_s
        @repr
      end
    end

    class ::Object
      @@location_cache = {}

      def should matcher, negate: false
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
          .match(/(.*)\.should/)
          .captures
          .first
          .strip

        desc = "#{var_name}#{negate ? ' not' : ''} #{matcher}"

        if matcher.execute(self, negate)
          Spectre.formatter.log(:info, "expect #{desc}", :ok, nil)
          Spectre.logger.info("expect #{desc} - ok")
        else
          actual = is_a?(String) ? "\"#{self}\"" : self
          raise ExpectationFailure.new(
            "expected #{desc}, but got #{actual || 'nothing'}",
            "got #{actual}"
          )
        end
      end

      def should_not matcher
        should(matcher, negate: true)
      end

      def or other_val
        OrWrapper.new(self, other_val)
      end

      def and other_val
        AndWrapper.new(self, other_val)
      end

      def should_be other
        to_s.should be other.to_s
      end

      def should_contain element
        should contain element
      end

      def should_not_be_empty
        should_not be_empty
      end
    end

    class << self
      def be expected_val
        Matcher.new(expected_val, __method__) do |val, negate, expected|
          expected.evaluate(proc { |x| negate ? x != val : x == val })
        end
      end

      def be_empty
        Matcher.new(nil, __method__) do |val, negate|
          negate ? !(val.nil? or val.empty?) : (val.nil? or val.empty?)
        end
      end

      def contain expected_val
        Matcher.new(expected_val, __method__) do |val, negate, expected|
          expected.evaluate(proc { |x| negate ? !val.include?(x) : val.include?(x) })
        end
      end

      def match regex
        Matcher.new(regex, __method__) do |val, negate, expected|
          expected.evaluate(proc { |x| negate ? !val.match?(x) : val.match?(x) })
        end
      end
    end
  end
end
