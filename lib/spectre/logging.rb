require_relative '../spectre'
require 'date'
require 'logger'

module Spectre
  module Logging
    module Status
      OK = '[ok]'
      FAILED = '[failed]'
      ERROR = '[error]'
      INFO = '[info]'
      SKIPPED = '[skipped]'
      DEBUG = '[debug]'
    end

    class ModuleLogger
      attr_reader :logger

      def initialize config, name
        @name = name
        @debug = config['debug']
        @logger = ::Logger.new(config['log_file'], progname: name)

        @logger.level = @debug ? ::Logger::DEBUG : ::Logger::INFO
      end

      def info message
        @logger.info(message)
        Spectre::Logging.add_log(message, :info, @name)
      end

      def debug message
        return unless @debug

        @logger.debug(message)
        Spectre::Logging.add_log(message, :debug, @name)
      end

      def warn message
        @logger.warn(message)
        Spectre::Logging.add_log(message, :warn, @name)
      end

      def error message
        @logger.error(message)
        Spectre::Logging.add_log(message, :error, @name)
      end
    end

    class << self
      @@debug = false
      @@logger = []

      def debug!
        @@debug = true
      end

      def debug?
        @@debug
      end

      def add logger
        @@logger.append(logger)
      end

      def start_subject subject
        delegate(:start_subject, subject)
      end

      def end_subject subject
        delegate(:end_subject, subject)
      end

      def start_context context
        delegate(:start_context, context)
      end

      def end_context context
        delegate(:end_context, context)
      end

      def start_spec spec, data=nil
        delegate(:start_spec, spec, data)
      end

      def end_spec spec, data=nil
        delegate(:end_spec, spec, data)
      end

      def log_subject subject
        begin
          start_subject(subject)
          yield
        ensure
          end_subject(subject)
        end
      end

      def log_context context
        begin
          start_context(context)
          yield
        ensure
          end_context(context)
        end
      end

      def log_spec spec, data=nil
        start_spec(spec, data)
        yield
        end_spec(spec, data)
      end

      def log_separator desc
        delegate(:log_separator, desc)
      end

      def start_group desc
        delegate(:start_group, desc)
      end

      def end_group desc
        delegate(:end_group, desc)
      end

      def log_process desc
        delegate(:log_process, desc)
      end

      def log_info message
        add_log(message, :info)
        delegate(:log_info, message)
      end

      def log_debug message
        return unless @@debug

        add_log(message, :debug)
        delegate(:log_debug, message)
      end

      def log_error spec, exception
        add_log(exception, :error)
        delegate(:log_error, spec, exception)
      end

      def log_skipped spec, message=nil
        delegate(:log_skipped, spec, message)
      end

      def log_status desc, status, annotation=nil
        delegate(:log_status, desc, status, annotation)
      end

      def group desc
        Spectre::Logging.start_group(desc)
        yield
        Spectre::Logging.end_group(desc)
      end

      def add_log message, level, logger_name='spectre'
        return unless Spectre::Runner.current

        Spectre::Runner.current.log.append([DateTime.now, message, level, logger_name])
      end

      alias_method :info, :log_info
      alias_method :log, :log_info
      alias_method :debug, :log_debug
      alias_method :separate, :log_separator

      private

      def delegate method, *args
        @@logger.each do |logger|
          logger.send(method, *args) if logger.respond_to? method
        end
      end
    end

    Spectre.delegate(:log, :info, :debug, :group, :separate, to: self)
  end
end
