require 'date'
require 'fileutils'

require_relative '../logging'

module Spectre::Logging
  class FileLogger
    def initialize config
      configure(config)
    end

    def log timestamp, message, level, name
      return unless @log_file
      line = "[#{timestamp}] #{level.to_s.upcase.rjust(5, ' ')} -- #{name}: #{message}\n"
      File.write(@log_file, line, mode: 'a')
    end

    private

    def configure config
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
end

Spectre.define 'spectre/logging/file' do |config, _logger, scope|
  handler = Spectre::Logging::FileLogger.new(config)
  scope.log.register(handler)
end
