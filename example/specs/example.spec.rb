describe 'Awesome API' do
  after do
    log 'finished'
  end

  it 'does a HTTP API request', tags: [:demo, :http, :request] do
    expect 'the response code to be 200' do

      http 'dummy_api' do
        method 'GET'
        path 'employee/1'

        header 'X-Custom', 'Some Value'
        header 'X-Custom2', 'Another Value'

        param 'foo', 'bar'
      end

      response.code.should_be '200'
    end

    expect 'the ID to be 1' do
      response.json.id.should_be '1'
    end

  end

  it 'fails an expectation', tags: [:failure] do
    log 'this is an info'

    expect 'the response code to be 201' do
      '400'.should_be '201'
    end
  end
end


describe 'Error API' do
  it 'raises an unexpected error', tags: [:fatal] do
    expect 'to be everything all right first' do
    end

    expect 'nothing to happen' do
      raise 'Oops!'
    end
  end

  it 'raises another error', tags: [:fatal] do
    expect 'nothing else' do
    end

    raise 'Something unexpected happened!'
  end
end


describe 'Some API' do
  before do
    @answer = 42
  end

  it 'uses a precreated variable', tags: [:success] do
    expect '@answer to be 42' do
      @answer.should_be 42
    end
  end

  it 'skips test if interrupted', tags: [:success, :skipped] do
    skip
  end

  it 'should do something with different things', with: ['this', 'that', 'other'], tags: [:success, :skipped] do |data|
    expect "somthing to happen with '#{data}'" do
    end
  end
end


describe 'Some API' do
  it 'runs successfully', tags: [:success] do
    expect 'foo to be foo' do
      'foo'.should_be 'foo'
    end

    fail_with 'no log dir found' if not `ls`.include? 'logs'
  end

  it 'fails with a message', tags: [:failure, :controlled] do
    expect 'to raise a message' do
      fail_with 'some controlled failure'
    end
  end

  context 'within a context' do
    it 'runs successfully', tags: [:success, :context] do
      expect 'foo to be foo' do
        'foo'.should_be 'foo'
      end

      fail_with 'no log dir found' if not `ls`.include? 'logs'
    end

    it 'fails with a message', tags: [:failure, :controlled, :context] do
      expect 'to raise a message' do
        fail_with 'some controlled failure'
      end
    end
  end
end