require 'ectoplasm'

module Spectre
  module Logger
    class Console
      @@level = 0
      @@width = 80
      @@indent = 2
      @@expectation = nil

      def initialize config
        # Do nothing for now. Maybe later. I dont't know.
      end

      def start_subject subject
        puts subject.desc.blue
      end

      def start_context context
        return unless context.__desc
        puts (' ' * indent) + context.__desc.magenta
        @@level += 1
      end

      def end_context context
        return unless context.__desc
        @@level -= 1
      end

      def start_spec spec, data=nil
        text = spec.desc
        text += " with #{data}" if data
        puts (' ' * indent) + text.cyan

        @@level += 1
      end

      def end_spec spec, data
        @@level -= 1
      end

      def log_expect desc
        print_line("expect #{desc}")
        @@expectation = desc
        @@level += 1
      end

      def log_status desc, status, annotation=nil
        status = status.green if status == Status::OK
        status = status.blue if status == Status::INFO
        status = status.grey if status == Status::DEBUG
        status = status.red if status == Status::FAILED
        status = status.red if status == Status::ERROR
        status = status.grey if status == Status::SKIPPED

        txt = status
        txt += ' ' + annotation if annotation

        @@level -= 1

        if @@expectation
          puts txt
        else
          print_line('', status)
        end

        @@expectation = nil
      end

      def log_info message
        print_line(message, Status::INFO.blue)
      end

      def log_debug message
        print_line(message, Status::DEBUG.grey)
      end

      def log_error spec, exception
        txt = Status::ERROR.red + ' - ' + exception.class.name.red
        print_line('', txt)
      end

      def log_skipped spec
        print_line('', Status::SKIPPED.grey)
      end

      private

      def indent
        (@@level+1) * @@indent
      end

      def print_line text='', status=nil
        puts if @@expectation

        ind = indent
        line = (' ' * indent) + text
        remaining = @@width - text.length - ind
        line += '.' * (@@width - text.length - ind) if remaining > 0

        print line

        if status
          puts status
          @@expectation = nil
        end
      end

    end
  end
end