require_relative '../spectre'
require 'date'

module Spectre
  module Logging
    class ModuleLogger
      def initialize name
        @name = name
      end

      def info message
        Spectre::Logging.log(message, :info, @name)
      end

      def debug message
        # return unless Logging.debug
        Spectre::Logging.log(message, :debug, @name)
      end

      def warn message
        Spectre::Logging.log(message, :warn, @name)
      end

      def error message
        Spectre::Logging.log(message, :error, @name)
      end
    end

    class << self
      @@debug = false
      @@handlers = []

      def log message, level, name=nil
        @@handlers.each do |handler|
          handler.send(level, message)
        end

        return unless Spectre::Runner.current
        Spectre::Runner.current.log << [DateTime.now, message, level, name]
      end
    end

    Spectre.register do |config|
      @@debug = config['debug']
    end
  end
end
