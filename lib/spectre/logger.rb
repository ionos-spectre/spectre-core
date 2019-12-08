require_relative 'helpers/console'

module Spectre::Logger
  module Status
    OK = '[ok]'.green
    FAILED = '[failed]'.red
    ERROR = '[error]'.red
    INFO = '[info]'
  end

  class << self

    def log_subject subject
      puts "#{subject.desc.blue}"
    end

    def log_spec spec
      puts "  #{spec.desc.cyan}"
    end

    def log_expectation desc
      print "    expect #{desc} " + ('.' * (50 - desc.length))
    end

    def log_info message
      puts ("    #{message} " + ('.' * (57 - message.length)) + Status::INFO).grey
    end

    def log_exception exception
      puts '    ' + ('.' * 58) + "#{Status::ERROR} #{exception.class.name.red}"
    end

    def log_status status
      print status + "\n"
    end

  end
end