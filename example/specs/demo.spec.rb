describe 'Awesome API' do
  before do
    @answer = 42
  end

  after do
    log 'finished'
  end

  it 'does a HTTP API request', tags: [:demo, :http] do
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

  it 'fails an expectation' do
    log 'this is an info'

    expect 'the response code to be 201' do
      '400'.should_be '201'
    end
  end

  it 'raises an unexpected error' do
    expect 'to be everything all right first' do
    end

    expect 'nothing to happen' do
      raise 'Oops!'
    end
  end

  it 'raises another error' do
    expect 'nothing else' do
    end

    raise 'Something unexpected happened!'
  end

  it 'runs successfully' do
    expect 'foo to be foo' do
      'foo'.should_be 'foo'
    end
  end

  it 'uses a precreated variable' do
    expect '@answer to be 42' do
      @answer.should_be 42
    end
  end

  it 'fails with a message' do
    expect 'to raise a message' do
      fail_with 'some controlled failure'
    end
  end
end