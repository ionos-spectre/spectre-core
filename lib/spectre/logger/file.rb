module Spectre
  module Logger
    class File
      def configure log_file
        @file_log = ::Logger.new log_file, progname: 'spectre'
        @file_log.level = Logger.debug? ? 'DEBUG' : 'INFO'
      end

      def start_subject subject
        @file_log.info "start running subject '#{subject.desc}'"
      end

      def end_subject subject
        @file_log.info "running subject '#{subject.desc}' finished"
      end

      def start_context context
        @file_log.info "start running context '#{context.__desc}'"
      end

      def end_context context
        @file_log.info "running context '#{context.__desc}' finished"
      end

      def start_spec spec, data=nil
        log_msg = "start running spec [#{spec.name}] '#{spec.desc}'"
        log_msg += " with data #{data}" if data
        @file_log.info log_msg
      end

      def end_spec spec, data=nil
        log_msg = "running spec [#{spec.name}] '#{spec.desc}'"
        log_msg += " with data #{data}" if data
        log_msg += " finished"
        @file_log.info log_msg
      end

      def log_expect desc
        @file_log.info "expect #{desc}"
      end

      def log_info message
        @file_log.info "[info] #{message}"
      end

      def log_debug message
        @file_log.debug "[debug] #{message}"
      end

      def log_error spec, exception
        file, line = exception.backtrace[0].match(/(.*\.rb):(\d+)/).captures
        @file_log.error "An unexpected errro occured at '#{file}:#{line}' while running spec '#{spec.name}': [#{exception.class}] #{exception.message}\n#{exception.backtrace.join "\n"}"
      end

      def log_skipped spec
        @file_log.warn "spec '#{spec.desc}' canceled by user"
      end

      def log_status desc, status, annotation: nil
        @file_log.info "expected #{desc}... #{status}"
      end
    end
  end
end