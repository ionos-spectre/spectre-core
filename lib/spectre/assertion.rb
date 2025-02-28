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

      # :nodoc:
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

      # :nodoc:
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

      # :nodoc:
      def to_s
        "#{@first} and #{@second}"
      end
    end

    class Evaluation
      @@location_cache = {}

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
          .find { |x| x.label.include? 'Spectre::Engine#load_files' or x.base_label == '<top (required)>' }

        path = location.path

        if @@location_cache.key?(path)
          file_content = @@location_cache[path]
        else
          file_content = File.read(path)
          @@location_cache[path] = file_content
        end

        @var_name = file_content
          .lines[location.lineno - 1]
          .strip
          .match(/[\s\(]([^\s]+|\[.*\]|{.*})\.(to|not_to)[\s\(]/)
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

      # :nodoc:
      def to_s
        @repr
      end
    end

    [
      ::Array, ::Hash, ::String, ::Integer, ::Float,
      ::NilClass, ::TrueClass, ::FalseClass, ::OpenStruct
    ].each do |cls|
      cls.define_method(:not_to) do |params|
        Evaluation.new(caller_locations, self, *params, negate: true)
      end

      cls.define_method(:to) do |params|
        Evaluation.new(caller_locations, self, *params)
      end
    end

    [::Array, ::Hash, ::String, ::Integer, ::Float, ::Regexp].each do |cls|
      cls.define_method(:or) do |other|
        OrWrapper.new(self, other)
      end

      cls.define_method(:and) do |other|
        AndWrapper.new(self, other)
      end
    end

    class << self
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
          proc do |expected, actual|
            expected = expected.to_s if actual.is_a? String
            actual.respond_to? :include? and actual.include?(expected)
          end
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
