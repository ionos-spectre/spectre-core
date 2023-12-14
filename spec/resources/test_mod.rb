require_relative '../../lib/spectre'

class TestExtension
  def initialize logger
    @logger = logger
  end

  def greet name
    @logger.info("Hello #{name}!")
  end
end

Spectre.define 'test' do |_config, logger|
  register :greet do |_run_info|
    TestExtension.new(logger)
  end
end
