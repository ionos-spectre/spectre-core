require_relative '../spectre'

Thread.abort_on_exception = true

module Spectre
  module Async
    class << self
      @@threads = {}

      def async name='default', &block
        unless @@threads.key? name
          @@threads[name] = []
        end

        @@threads[name] << Thread.new(&block)
      end

      def await name='default'
        return unless @@threads.key? name

        threads = @@threads[name].map { |x| x.join() }

        @@threads.delete(name)

        threads.map { |x| x.value }
      end
    end

    Spectre.delegate :async, :await, to: self
  end
end
