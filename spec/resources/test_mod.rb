class TestExtension
  def initialize logger
    @logger = logger
  end

  def greet name
    @logger.info("Hello #{name}!")
  end
end

define 'test' do |config, logger|
  register :greet, TestExtension.new(logger)
end
