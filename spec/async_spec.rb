# Mock the `define' and `register' methods of the Spectre ModuleContext
# before loading spectre modules
def define name
end

def register *args
end

require_relative '../lib/spectre/async'

RSpec.describe 'spectre/async' do
  before do
    @async_ctx = Spectre::Async::AsyncContext.new(Spectre::Logging::ModuleLogger.new('spectre/async', Spectre::SpectreScope.new))
  end

  it 'runs a block async after main' do
    name = 'do something'

    values = []

    @async_ctx.async name do
      sleep 0.5
      values << 'Hello from thread!'
    end

    values << 'Hello from main!'

    @async_ctx.await(name)

    expect(values[0]).to eq('Hello from main!')
    expect(values[1]).to eq('Hello from thread!')
  end

  it 'runs a block before after main' do
    name = 'do something'

    values = []

    @async_ctx.async name do
      values << 'Hello from thread!'
    end

    sleep 0.5

    values << 'Hello from main!'

    @async_ctx.await(name)

    expect(values[0]).to eq('Hello from thread!')
    expect(values[1]).to eq('Hello from main!')
  end

  it 'runs a block async with default name' do
    values = []

    @async_ctx.async do
      sleep 0.5
      values << 'Hello from thread!'
    end

    values << 'Hello from main!'

    @async_ctx.await()

    expect(values[0]).to eq('Hello from main!')
    expect(values[1]).to eq('Hello from thread!')
  end

  it 'runs a block async and returns values' do
    @async_ctx.async do
      'This is the async result'
    end

    result = @async_ctx.await.first

    expect(result).to eq('This is the async result')
  end

  it 'runs multiple async blocks with same name' do
    @async_ctx.async do
      'first result'
    end

    @async_ctx.async do
      sleep 0.1
      'second result'
    end

    @async_ctx.async 'test' do
      sleep 0.1 # let the second thread finish first
      'first test result'
    end

    @async_ctx.async 'test' do
      'second test result'
    end

    results = @async_ctx.await()

    expect(results[0]).to eq('first result')
    expect(results[1]).to eq('second result')

    test_results = @async_ctx.await('test')

    # results are returned in async start order, not in async finish order
    expect(test_results[0]).to eq('first test result')
    expect(test_results[1]).to eq('second test result')
  end
end
