require_relative '../spectre'

Thread.abort_on_exception = true

module Spectre::Async
  class AsyncContext
    def initialize logger
      @logger = logger
      @threads = {}
    end

    def async desc='default', &block
      @threads[desc] = [] unless @threads.key? desc

      @logger.info("asynchorously do #{desc}")

      @threads[desc] << Thread.new do
        block.call
      end
    end

    def await desc='default'
      return unless @threads.key? desc

      @logger.info("waiting for #{desc} to finish")

      thread_group = @threads[desc].map { |x| x.join() }

      @threads.delete(desc)

      thread_group.map { |x| x.value }
    end

    alias :wait_for :await
  end
end

Spectre.define 'spectre/async' do |_config, logger, _scope|
  async_ctx = Spectre::Async::AsyncContext.new(logger)

  register :async, :await, :wait_for do |_run_info|
    async_ctx
  end
end
