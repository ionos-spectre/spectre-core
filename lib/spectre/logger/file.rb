module Spectre
  module Logger
    class File
      def initialize config
        raise 'No log format section in config for console logger' unless config.key? 'log_format' and config['log_format'].key? 'file'

        @config = config['log_format']['file']
        @fmt_start_group = @config['start_group']
        @fmt_end_group = @config['end_group']
        @fmt_sep = @config['separator']

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
        if context and context.__desc
          @file_log.debug "start running context '#{context.__desc}'"
        else
          @file_log.debug "start running main context of #{context.__subject.desc}"
        end
      end

      def end_context context
        if context and context.__desc
          @file_log.debug "context '#{context.__desc}' finished"
        else
          @file_log.debug "main context finished of #{context.__subject.desc}"
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

      def log_separator desc
        desc = @fmt_sep.gsub('<desc>', desc) if @fmt_sep
        @file_log.info desc
      end

      def start_group desc
        desc = @fmt_start_group.gsub('<desc>', desc) if @fmt_start_group
        @file_log.info desc
      end

      def end_group desc
        desc = @fmt_end_group.gsub('<desc>', desc) if @fmt_end_group
        @file_log.info desc
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
        @file_log.error "An unexpected error occured at '#{file}:#{line}' while running spec '#{spec.name}': [#{exception.class}] #{exception.message}\n#{exception.backtrace.join "\n"}"
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
