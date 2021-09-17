require 'ostruct'

def to_recursive_ostruct(hash)
  OpenStruct.new(
    hash.each_with_object({}) do |(key, val), memo|
      memo[key] = val.is_a?(Hash) ? to_recursive_ostruct(val) : val
    end
  )
end

module Spectre
  module Environment
    class << self
      @@environment = OpenStruct.new

      def env
        @@environment
      end
    end

    Spectre.register do |config|
      @@environment = to_recursive_ostruct(config)
      @@environment.freeze
    end

    Spectre.delegate :env, to: self
  end
end