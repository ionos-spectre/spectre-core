require 'date'

module Spectre
  module Logging
    class SpectreLogger
      def initialize name, scope
        @name = name
        @scope = scope
        @handlers = []
      end

      [:info, :debug, :warn, :error].each do |level|
        define_method(level) do |message|
          log(message, level)
        end
      end

      def log message, level
        log_entry = [DateTime.now, message, level, @name]

        @handlers.each do |handler|
          handler.send(:log, *log_entry) if handler.respond_to? :log
        end

        @scope.runs.last.log << log_entry
      end

      def register module_logger
        @handlers << module_logger
      end

      def configure config
        @debug = config['debug']

        @handlers.each do |handler|
          handler.configure(config) if handler.respond_to? :configure
        end
      end
    end
  end
end
