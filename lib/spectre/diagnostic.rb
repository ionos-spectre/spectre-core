require_relative '../spectre'

module Spectre
  module Diagnostic
    module Stopwatch
      @@duration = 0.0

      class << self
        def start_watch
          @@start_time = Time.now
        end

        def stop_watch
          @@end_time = Time.now
        end

        def measure
          start_watch
          yield
          stop_watch
        end

        def duration
          @@end_time - @@start_time
        end

        def started_at
          @@start_time
        end

        def finished_at
          @@end_time
        end
      end

      Spectre.delegate :start_watch, :stop_watch, :duration, :measure, to: self
    end
  end
end