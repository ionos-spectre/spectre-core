require 'ostruct'

module Spectre
  module Environment
    class << self
      @@environment = {}

      def env
        @@environment
      end
    end

    Spectre.register do |config|
      @@environment = OpenStruct.new config
      @@environment.freeze
    end

    Spectre.delegate :env, to: Environment
  end
end