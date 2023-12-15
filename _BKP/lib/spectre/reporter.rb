module Spectre
  module Reporter
    @@reporters = {}

    def self.register name, &block
      @@reporters[name] = block
    end

    def self.report run_infos, config, reporters=nil
      @@reporters
        .select { |name, _| reporters.nil? or reporters.include? name }
        .each do |_name, block|
          block.call(run_infos, config)
        end
    end
  end
end
