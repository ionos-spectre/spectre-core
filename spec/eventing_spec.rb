require_relative '../lib/spectre/core'
require_relative '../lib/spectre/runner'
require_relative '../lib/spectre/assertion'

require 'json'

RSpec.describe 'spectre/eventing' do
  it 'does load event handlers' do
    class MockHandler
      attr_reader :exec_count

      def initialize
        @exec_count = 0
      end

      def foo _message, *_args, **_kwargs
        @exec_count += 1
      end
    end

    spectre_scope = Spectre::SpectreScope.new
    mock_handler = MockHandler.new

    spectre_scope.event.register(mock_handler)
    spectre_scope.event.trigger(:foo, 'some message')

    expect(mock_handler.exec_count).to eq(1)
  end
end
