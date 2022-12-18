class TestExtension
  def initialize logger
    @logger = logger
  end

  def greet name
    @logger.info("Hello #{name}!")
  end
end

define 'test' do |config, logger|
  register :greet do |_run_info|
    TestExtension.new(logger)
  end
end
