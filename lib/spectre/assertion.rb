require 'ostruct'
require_relative 'logger'

class Object
  def should_be(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.to_s == val.to_s
  end

  def should_be_empty
    raise Spectre::ExpectationFailure.new('empty', self) unless self == nil
  end

  def should_not_be(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.to_s != val.to_s
  end

  def should_not_be_empty
    raise Spectre::ExpectationFailure.new('not empty', self) unless self != nil
  end
end


class NilClass
  def should_be(val)
    raise Spectre::ExpectationFailure.new(val, 'nil') unless val == nil
  end

  def should_be_empty
  end

  def should_not_be(val)
    raise Spectre::ExpectationFailure.new(val, 'nil') unless val != nil
  end

  def should_not_be_empty
    raise Spectre::ExpectationFailure.new('not empty', 'nil')
  end
end


class Hash
  def should_contain(other)
    raise Spectre::ExpectationFailure.new(other, self) unless self.merge(other) == self
  end

  def should_not_contain(other)
    raise Spectre::ExpectationFailure.new(other, self) unless self.merge(other) != self
  end
end


class Array
  def should_contain(val)
    list = self

    if val.is_a? Hash and self.all? { |x| x.is_a? OpenStruct or x.is_a? Hash }
      list = self.map { |x| OpenStruct.new(x) }
      val = OpenStruct.new(val)
    end

    raise Spectre::ExpectationFailure.new(val, list) unless list.include? val
  end

  def should_not_contain(val)
    list = self

    if val.is_a? Hash and self.all? { |x| x.is_a? OpenStruct or x.is_a? Hash }
      list = self.map { |x| OpenStruct.new(x) }
      val = OpenStruct.new(val)
    end

    raise Spectre::ExpectationFailure.new(val, list) if list.include? val
  end

  def should_be_empty
    raise Spectre::ExpectationFailure.new('empty list', self) unless self.length == 0
  end

  def should_not_be_empty
    raise Spectre::ExpectationFailure.new('no empty list', self) unless self.length > 0
  end
end


class String
  def should_contain(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.include? val
  end

  def should_not_contain(val)
      raise Spectre::ExpectationFailure.new(val, self) if self.include? val
  end

  def should_match(regex)
    raise Spectre::ExpectationFailure.new(regex, self) unless self.match(regex)
  end

  def should_not_match(regex)
    raise Spectre::ExpectationFailure.new(regex, self) if self.match(regex)
  end
end


module Spectre
  module Assertion
    class << self
      def expect desc
        begin
          Logger.log_process("expect #{desc}")
          yield
          Logger.log_status(desc, Logger::Status::OK)

        rescue Interrupt => e
          raise e

        rescue Spectre::ExpectationFailure => e
          Logger.log_status(desc, Logger::Status::FAILED)
          raise Spectre::ExpectationFailure.new(desc, e.message), cause: nil

        rescue Exception => e
          Logger.log_status(desc, Logger::Status::ERROR)
          raise Spectre::ExpectationFailure.new(desc, e.message), cause: e
        end
      end

      def check desc
        full_desc = "check #{desc}"

        begin
          Logger.log_process(full_desc)
          yield
          Logger.log_status(full_desc, Logger::Status::OK)

        rescue Interrupt => e
          raise e

        rescue Exception => e
          Logger.log_status(full_desc, Logger::Status::FAILED)
          raise Spectre::ExpectationFailure.new(desc + ' to succeed', ''), cause: nil
        end
      end

      def observe desc
        begin
          Logger.log_process(desc)
          yield
          Logger.log_status(desc, Logger::Status::OK)

        rescue Interrupt => e
          raise e
        end
      end

      def fail_with message
        raise Spectre::ExpectationFailure.new(nil, message)
      end
    end

    Spectre.delegate :expect, :check, :observe, :fail_with, to: self
  end
end
