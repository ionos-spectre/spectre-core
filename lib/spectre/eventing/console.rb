require 'ectoplasm'

module Spectre::Eventing
  class ::String
    alias :ok :green
    alias :error :red
    alias :failed :red
    alias :info :blue
    alias :debug :grey
  end

  class ConsoleLogger
    def initialize
      @indent = 2
      @width = 80
      @level = 0
    end

    def start_subject subject
      write_line(subject.desc.blue)
      @level += 1
    end

    def end_subject subject
      @level -= 1
    end

    def start_context context
      return unless context.__desc
      write_line(context.__desc)
      @level += 1
    end

    def end_context context
      return unless context.__desc
      @level -= 1
    end

    def start_setup run_info
      write_line('setup'.magenta)
      @level += 1
    end

    def end_setup run_info
      @level -= 1
    end

    def start_teardown run_info
      write_line('teardown'.magenta)
      @level += 1
    end

    def end_teardown run_info
      @level -= 1
    end

    def start_before run_info
      write_line('before'.magenta)
      @level += 1
    end

    def end_before run_info
      @level -= 1
    end

    def start_after run_info
      write_line('after'.magenta)
      @level += 1
    end

    def end_after run_info
      @level -= 1
    end

    def start_spec run_info
      write_line(run_info.spec.desc.cyan)
      @level += 1
    end

    def end_spec run_info
      @level -= 1
    end

    def start_group desc
      write_line(desc.yellow)
      @level += 1
    end

    def end_group desc
      @level -= 1
    end

    def start_expect desc
      write_line("expect #{desc}", fill: true, newline: false)
    end

    def end_expect desc, status, message
      text = "[#{status}]".send(status)
      text += " - #{message}" if message
      puts text
    end

    def log message, level
      write_line(message, fill: true, newline: false)
      puts "[#{level}]".send(level)
    end

    def spec_skip run_info, message
      write_line('', fill: true, newline: false)
      status = '[skipped]'

      status += ' - ' + message if message
      puts status.grey
    end

    def spec_error run_info, error
      write_line('', fill: true, newline: false)
      status = '[error]'

      status += ' - ' + error.message if error
      puts status.red
    end

    private

    def indent
      ' ' * (@indent * @level)
    end

    def fill text
      text + ('.' * (@width - text.length - @indent * @level))
    end

    def write_line text, fill: false, newline: true
      text = fill(text) if fill
      text = indent() + text

      if newline
        puts text
      else
        print text
      end
    end
  end

  Spectre.register do |_|
    Spectre::Eventing.register(ConsoleLogger.new)
  end
end
