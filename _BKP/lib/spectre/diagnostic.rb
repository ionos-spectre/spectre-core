require_relative '../spectre'

module Spectre
  module Diagnostic
    class Stopwatch
      def initialize
        @__started = nil
        @__finished = nil
      end

      def start_watch
        @__started = Time.now
      end

      def stop_watch
        @__finished = Time.now
      end

      def measure
        start_watch()
        yield
        stop_watch()
      end

      def duration
        @__finished - @__started
      end
    end
  end
end

Spectre::SpectreScope.define 'spectre/diagnostic' do |_config, _logger, _scope|
  register :start_watch, :stop_watch, :duration, :measure do
    Spectre::Diagnostic::Stopwatch.new
  end
end
