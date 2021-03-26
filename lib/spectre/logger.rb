module Spectre
  module Logger
    module Status
      OK = '[ok]'
      FAILED = '[failed]'
      ERROR = '[error]'
      INFO = '[info]'
      SKIPPED = '[skipped]'
      DEBUG = '[debug]'
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
        @@logger.append logger
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
        start_subject(subject)
        yield
        end_subject(subject)
      end

      def log_context context
        start_context(context)
        yield
        end_context(context)
      end

      def log_spec spec, data=nil
        start_spec(spec, data)
        yield
        end_spec(spec, data)
      end

      def log_expect desc
        delegate(:log_expect, desc)
      end

      def log_info message
        delegate(:log_info, message)
      end

      def log_debug message
        return unless @@debug
        delegate(:log_debug, message)
      end

      def log_error spec, exception
        delegate(:log_error, spec, exception)
      end

      def log_skipped spec
        delegate(:log_skipped, spec)
      end

      def log_status desc, status, annotation=nil
        delegate(:log_status, desc, status, annotation)
      end

      def log message
        Logger.log_info message
      end

      def debug message
        Logger.log_debug message
      end

      alias_method :info, :log

      private

      def delegate method, *args
        @@logger.each do |logger|
          logger.send(method, *args) if logger.respond_to? method
        end
      end
    end

    Spectre.delegate :log, :info, :debug, to: self
  end
end