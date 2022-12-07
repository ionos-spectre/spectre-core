require 'date'
require 'fileutils'

require_relative '../logging'

module Spectre::Logging
  module FileLogger
    @log_file = nil

    def self.log timestamp, message, level, name
      return unless @log_file
      line = "[#{timestamp}] #{level.to_s.upcase.rjust(5, ' ')} -- #{name}: #{message}\n"
      File.write(@log_file, line, mode: 'a')
    end

    def self.configure config
      return unless config.key? 'log_file'

      now = DateTime.now

      @log_file = config['log_file'].frmt({
        shortdate: now.strftime('%Y-%m-%d'),
        date: now.strftime('%Y-%m-%d_%H%M%S'),
        timestamp: now.strftime('%s'),
        subject: 'spectre',
      })

      log_dir = File.dirname(@log_file)
      FileUtils.makedirs(log_dir)
    end
  end

  Spectre::Logging.register(FileLogger)
end