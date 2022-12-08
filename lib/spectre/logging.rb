require_relative '../spectre'

require 'date'

module Spectre
  module Logging
    class ModuleLogger
      def initialize name
        @name = name
      end

      [:info, :debug, :warn, :error].each do |level|
        define_method(level) do |message|
          Spectre::Logging.log(message, level, @name)
        end
      end
    end

    class << self
      @@handlers = []

      def log message, level, name=nil
        log_entry = [DateTime.now, message, level, name]

        @@handlers.each do |handler|
          handler.send(:log, *log_entry) if handler.respond_to? :log
        end

        return unless Spectre::Runner.current
        Spectre::Runner.current.log << log_entry
      end

      def register module_logger
        @@handlers << module_logger
      end

      def configure config
        @@debug = config['debug']

        @@handlers.each do |handler|
          handler.configure(config) if handler.respond_to? :configure
        end
      end
    end

    Spectre.register(self)
  end
end
