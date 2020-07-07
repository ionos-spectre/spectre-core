require_relative '../helpers/console'

module Spectre::Logger
  module Status
    OK = '[ok]'.green
    FAILED = '[failed]'.red
    ERROR = '[error]'.red
    INFO = '[info]'.blue
    SKIPPED = '[skipped]'.grey
  end

  module Console
    @@level = 0
    @@width = 80
    @@indent = 2

    class << self

      def log_subject subject
        puts "#{subject.desc.blue}"
      end

      def log_context context
        if context.desc
          puts "  #{context.desc.magenta}"
          @@level += 1
          yield
          @@level -= 1
        else
          yield
        end
      end

      def log_spec spec, data=nil
        text = spec.desc
        text += " with #{data}" if data
        print_line text.cyan

        @@level += 1
        yield
        @@level -= 1
      end

      def log_expect desc
        print_line("expect #{desc}", fill: true)
      end

      def log_info message
        print_line(message, fill: true)
        log_status(Spectre::Logger::Status::INFO)
      end

      def log_error exception
        print_line('', fill: true)
        log_status(Spectre::Logger::Status::ERROR, annotation: exception.class.name.red)
      end

      def log_skipped
        print_line('', fill: true)
        log_status(Spectre::Logger::Status::SKIPPED)
      end

      def log_status status, annotation: nil
        txt = status
        txt += ' ' + annotation if annotation
        print txt + "\n"
      end

      private

      def print_line text, fill: false
        indent = (@@level+1) * @@indent
        line = (' ' * indent) + text
        remaining = @@width - text.length - indent
        line += '.' * (@@width - text.length - indent) if fill and remaining > 0
        line += "\n" unless fill
        print line
      end

    end
  end
end