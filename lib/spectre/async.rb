require_relative '../spectre'

Thread.abort_on_exception = true

module Spectre
  module Async
    class << self
      Thread.current[:spectre_threads] = {}

      def async name='default', &block
        unless threads.key? name
          threads[name] = []
        end

        current_thread = Thread.current

        threads[name] << Thread.new do
          Thread.current[:parent] = current_thread
          block.call
        end
      end

      def await name='default'
        return unless threads.key? name

        thread_group = threads[name].map { |x| x.join() }

        threads.delete(name)

        thread_group.map { |x| x.value }
      end

      private

      def threads
        Thread.current[:spectre_threads]
      end
    end

    Spectre.delegate(:async, :await, to: self)
  end
end