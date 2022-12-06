require_relative '../spectre'
require 'date'

module Spectre
  module Logging
    class ModuleLogger
      @@debug = false
      @@handlers = []

      def initialize name
        @name = name
      end

      def info message
        add_log(message, :info)
      end

      def debug message
        # return unless Logging.debug
        add_log(message, :debug)
      end

      def warn message
        add_log(message, :warn)
      end

      def error message
        add_log(message, :error)
      end

      private

      def add_log message, level
        @@handlers.each do |handler|
          handler.send(level, message)
        end

        return unless Spectre::Runner.current
        Spectre::Runner.current.log << [DateTime.now, message, level, @name]
      end
    end

    # Spectre.register do |config|
    #   @@debug = config['debug']
    # end
  end
end
