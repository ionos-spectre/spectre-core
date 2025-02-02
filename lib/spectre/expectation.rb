require_relative 'assertion'

module Spectre
  ##
  # This module provides old (Spectre v1) style assertions
  # for compatibility reasons. This will be removed in the future
  #
  module Expectation
    class ::Object
      def should_be value
        predicate = proc { |expected, actual| expected.to_s == actual.to_s }
        value = Spectre::Assertion::ValueWrapper.wrap(value)
        success = value.evaluate(predicate, self, false)

        return if success

        raise Failure, "#{self} should be #{value}"
      end

      def should_be_empty
        predicate = proc { |_, actual| actual.nil? or (actual.respond_to?(:empty?) and actual.empty?) }
        value = Spectre::Assertion::ValueWrapper.wrap(nil)
        success = value.evaluate(predicate, self, false)

        return if success

        raise Failure, "#{self} should be empty"
      end

      def should_not_be(value)
        predicate = proc { |expected, actual| expected.to_s == actual.to_s }
        value = Spectre::Assertion::ValueWrapper.wrap(value)
        success = value.evaluate(predicate, self, true)

        return if success

        raise Failure, "#{self} should not be #{value}"
      end

      def should_not_exist
        predicate = proc { |expected, _| expected.respond_to? :nil? and expected.nil? }
        value = Spectre::Assertion::ValueWrapper.wrap(value)
        success = value.evaluate(predicate, self, true)

        return if success

        raise Failure, "#{self} should not exist"
      end

      def should_not_be_empty
        predicate = proc { |_, actual| actual.nil? or (actual.respond_to?(:empty?) and actual.empty?) }
        value = Spectre::Assertion::ValueWrapper.wrap(nil)
        success = value.evaluate(predicate, self, true)

        return if success

        raise Failure, "#{self} should not be empty"
      end

      def should_contain value
        predicate = proc { |expected, actual| actual.respond_to? :include? and actual.include?(expected) }
        value = Spectre::Assertion::ValueWrapper.wrap(value)
        success = value.evaluate(predicate, self, false)

        return if success

        raise Failure, "#{self} should contain #{value}"
      end

      def should_not_contain value
        predicate = proc { |expected, actual| actual.respond_to? :include? and actual.include?(expected) }
        value = Spectre::Assertion::ValueWrapper.wrap(value)
        success = value.evaluate(predicate, self, true)

        return if success

        raise Failure, "#{self} should not contain #{value}"
      end
    end
  end
end
