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

define 'spectre/async' do |_config, _logger|
  register :async, :await, :wait_for, Spectre::Async::AsyncContext.new
end