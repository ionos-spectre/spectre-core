module Spectre::Diagnostic
  @@duration = 0.0

  def self.measure
    start_time = Time.now
    yield
    end_time = Time.now

    @@duration = end_time - start_time
  end

  def self.duration
    @@duration
  end

  Spectre.delegate :duration, :measure, to: self
end
