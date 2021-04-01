module Spectre
  module Logger
    class File
      def initialize config
        @file_log = ::Logger.new config['log_file'], progname: 'spectre'
        @file_log.level = config['debug'] ? 'DEBUG' : 'INFO'
      end

      def start_subject subject
        @file_log.debug "start running subject '#{subject.desc}'"
      end

      def end_subject subject
        @file_log.debug "subject '#{subject.desc}' finished"
      end

      def start_context context
        if context
          @file_log.debug "start running context '#{context.__desc}'"
        else
          @file_log.debug 'start running main context'
        end
      end

      def end_context context
        if context
          @file_log.debug "context '#{context.__desc}' finished"
        else
          @file_log.debug 'main context finished'
        end
      end

      def start_spec spec, data=nil
        log_msg = "start running spec [#{spec.name}] '#{spec.desc}'"
        log_msg += " with data #{data}" if data
        @file_log.debug log_msg
      end

      def end_spec spec, data=nil
        log_msg = "running spec [#{spec.name}] '#{spec.desc}'"
        log_msg += " with data #{data}" if data
        log_msg += " finished"
        @file_log.debug log_msg
      end

      def log_process desc
        @file_log.debug desc
      end

      def log_info message
        @file_log.info "#{Status::INFO} #{message}"
      end

      def log_debug message
        @file_log.debug "#{Status::DEBUG} #{message}"
      end

      def log_error spec, exception
        file, line = exception.backtrace[0].match(/(.*\.rb):(\d+)/).captures
        @file_log.error "An unexpected errro occured at '#{file}:#{line}' while running spec '#{spec.name}': [#{exception.class}] #{exception.message}\n#{exception.backtrace.join "\n"}"
      end

      def log_skipped spec
        @file_log.warn "spec '#{spec.desc}' canceled by user"
      end

      def log_status desc, status, annotation=nil
        msg = "expected #{desc}...#{status.upcase}"
        msg += " - #{annotation}" if annotation
        @file_log.debug msg
      end
    end
  end
end