module Firehouse
  class Phone
    def initialize config, logger
      @config = config['phone']
      @logger = logger
    end

    def call(number, &)
      @logger.log(Logger::Severity::INFO, "calling #{number}", 'firehouse/phone')

      instance_eval(&)

      OpenStruct.new({
        number: number,
        caller: 'Janine Melnitz',
        message: 'Can I help you?',
        question: @question,
      })
    end

    def ask message
      @question = message
    end
  end

  Spectre::Engine.register(Phone, :call)
end
