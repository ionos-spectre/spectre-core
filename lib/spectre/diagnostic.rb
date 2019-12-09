module Spectre::Diagnostic
  @@duration = 0.0

  class << self
    def start
      @@start_time = Time.now
    end

    def stop
      @@end_time = Time.now
    end

    def measure
      start
      yield
      stop
    end

    def duration
      @@end_time - @@start_time
    end
  end

  Spectre.delegate :start, :stop, :duration, :measure, to: self
end
