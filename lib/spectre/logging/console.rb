require 'ectoplasm'

module Spectre
  module Logging
    class Console
      def initialize config
        @indent = 2
        @width = 80

        if config.key? 'log_format'
          @config = config['log_format']['console'] || {}
          @indent = @config['indent'] || @indent
          @width = @config['width'] || @width
          @fmt_end_context = @config['end_context']
          @fmt_sep = @config['separator']
          @fmt_start_group = @config['start_group']
          @fmt_end_group = @config['end_group']
        end

        @process = nil
        @level = 0
      end

      def start_subject subject
        puts subject.desc.blue
      end

      def start_context context
        return unless context.__desc

        puts (' ' * indent) + context.__desc.magenta
        @level += 1
      end

      def end_context context
        return unless context.__desc

        @level -= 1
        puts (' ' * indent) + @fmt_end_context.gsub('<desc>', context.__desc).magenta if @fmt_end_context
      end

      def start_spec spec, data=nil
        text = spec.desc
        text += " with #{data}" if data
        puts (' ' * indent) + text.cyan

        @level += 1
      end

      def end_spec _spec, _data
        @level -= 1
      end

      def log_separator desc
        if desc
          desc = @fmt_sep.gsub('<indent>', ' ' * indent).gsub('<desc>', desc) if @fmt_sep
          puts desc.blue
        else
          puts
        end
      end

      def start_group desc
        desc = @fmt_start_group.gsub('<desc>', desc) if @fmt_start_group
        puts (' ' * indent) + desc.blue
        @level += 1
      end

      def end_group desc
        if desc and @fmt_start_group
          desc = @fmt_start_group.gsub('<desc>', desc) if @fmt_start_group
          puts (' ' * indent) + desc.blue
        end

        @level -= 1
      end

      def log_process desc
        print_line(desc)
        @process = desc
        @level += 1
      end

      def log_status _desc, status, annotation=nil
        status = status.green if status == Status::OK
        status = status.blue if status == Status::INFO
        status = status.grey if status == Status::DEBUG
        status = status.red if status == Status::FAILED
        status = status.red if status == Status::ERROR
        status = status.grey if status == Status::SKIPPED

        txt = status
        txt += ' ' + annotation if annotation

        @level -= 1

        if @process
          puts txt
        else
          print_line('', status)
        end

        @process = nil
      end

      def log_info message
        print_line(message, Status::INFO.blue)
      end

      def log_debug message
        print_line(message, Status::DEBUG.grey)
      end

      def log_error _spec, exception
        txt = (Status::ERROR + ' - ' + exception.class.name).red
        print_line('', txt)
      end

      def log_skipped _spec, message=nil
        txt = Status::SKIPPED

        unless message.nil?
          txt += ' - ' + message
        end

        print_line('', txt.grey)
      end

      private

      def indent
        (@level+1) * @indent
      end

      def print_line text='', status=nil
        puts if @process

        ind = indent
        line = (' ' * indent) + text
        remaining = @width - text.length - ind
        line += '.' * (@width - text.length - ind) if remaining > 0

        print line

        if status
          puts status
          @process = nil
        end
      end
    end

    Spectre.register do |config|
      Spectre::Logging.add Console.new(config)
    end
  end
end
