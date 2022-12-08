require_relative '../spectre'

module Spectre
  module Diagnostic
    module Stopwatch
      class << self
        def start_watch
          Thread.current[:spectre_stopwatch_started] = Time.now
        end

        def stop_watch
          Thread.current[:spectre_stopwatch_finished] = Time.now
        end

        def measure
          start_watch()
          yield
          stop_watch()
        end

        def duration
          finished_at - started_at
        end

        def started_at
          Thread.current[:spectre_stopwatch_started]
        end

        def finished_at
          Thread.current[:spectre_stopwatch_finished]
        end
      end

      Spectre.delegate(:start_watch, :stop_watch, :duration, :measure, to: self)
    end
  end
end
