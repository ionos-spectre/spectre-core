module Spectre
  module Reporter
    @@reporters = []

    def self.add reporter
      raise NotImplementedError.new("#{reporter} does not implement `report' method") unless reporter.respond_to? :report
      @@reporters.append(reporter)
    end

    def self.report run_infos
      @@reporters.each do |reporter|
        reporter.report(run_infos)
      end
    end
  end
end
