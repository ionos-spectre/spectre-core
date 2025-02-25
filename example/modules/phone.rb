module Firehouse
  class Phone
    # Add a contructor which accepts a config and logger object
    # +config+ is the whole spectre config, merged from +spectre.yml+
    # and the environment files. It is recommended to define a dedicated
    # config section for your module and extract that config for later use.
    def initialize config, logger
      @config = config['phone']
      @logger = logger
    end

    def call(number, &)
      # Use the logger object as usual. It is recommended to pass the +progname+
      # parameter to distinguish log messages from other modules.
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

  # Finally register the module class and names of methods, which should be
  # exposed in every Spectre scope.
  Spectre::Engine.register(Phone, :call)
end
