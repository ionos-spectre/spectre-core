require 'spectre/async'

RSpec.describe 'spectre/async' do
  it 'runs a block async after main' do
    name = 'do something'

    values = []

    Spectre::Async.async name do
      sleep 0.5
      values << 'Hello from thread!'
    end

    values << 'Hello from main!'

    Spectre::Async.await(name)

    expect(values[0]).to eq('Hello from main!')
    expect(values[1]).to eq('Hello from thread!')
  end

  it 'runs a block before after main' do
    name = 'do something'

    values = []

    Spectre::Async.async name do
      values << 'Hello from thread!'
    end

    sleep 0.5

    values << 'Hello from main!'

    Spectre::Async.await(name)

    expect(values[0]).to eq('Hello from thread!')
    expect(values[1]).to eq('Hello from main!')
  end

  it 'runs a block async with default name' do
    values = []

    Spectre::Async.async do
      sleep 0.5
      values << 'Hello from thread!'
    end

    values << 'Hello from main!'

    Spectre::Async.await()

    expect(values[0]).to eq('Hello from main!')
    expect(values[1]).to eq('Hello from thread!')
  end

  it 'runs a block async and returns values' do
    Spectre::Async.async do
      'This is the async result'
    end

    result = Spectre::Async.await.first

    expect(result).to eq('This is the async result')
  end

  it 'runs multiple async blocks with same name' do
    Spectre::Async.async do
      'first result'
    end

    Spectre::Async.async do
      sleep 0.1
      'second result'
    end

    Spectre::Async.async 'test' do
      sleep 0.1 # let the second thread finish first
      'first test result'
    end

    Spectre::Async.async 'test' do
      'second test result'
    end

    results = Spectre::Async.await()

    expect(results[0]).to eq('first result')
    expect(results[1]).to eq('second result')

    test_results = Spectre::Async.await('test')

    # results are returned in async start order, not in async finish order
    expect(test_results[0]).to eq('first test result')
    expect(test_results[1]).to eq('second test result')
  end
end
