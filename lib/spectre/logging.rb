require 'date'

module Spectre
  module Logging
    class SpectreLogger
      def initialize scope
        @scope = scope
        @handlers = []
        @mod_loggers = {}
      end

      def log message, level, name
        log_entry = [DateTime.now, message, level, name]

        @handlers.each do |handler|
          handler.send(:log, *log_entry) if handler.respond_to? :log
        end

        @scope.runs.last.log << log_entry if @scope.runs.any?
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

      def create_logger name
        return @mod_loggers[name] if @mod_loggers.key? name
        logger = ModuleLogger.new(name, self)
        @mod_loggers[name] = logger
      end
    end

    class ModuleLogger
      def initialize name, logger
        @name = name
        @logger = logger
      end

      [:info, :debug, :warn, :error].each do |level|
        define_method(level) do |message|
          @logger.log(message, level, @name)
        end
      end
    end
  end
end
