require_relative '../spectre'

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
    @@environment = OpenStruct.new

    def self.env
      Thread.current[:spectre_env] || (Thread.current[:parent].nil? ? nil : Thread.current[:parent][:spectre_env])
    end

    Spectre.register do |config|
      env = to_recursive_ostruct(config)
      env.freeze

      Thread.current[:spectre_env] = env
    end

    Spectre.delegate :env, to: self
  end
end
