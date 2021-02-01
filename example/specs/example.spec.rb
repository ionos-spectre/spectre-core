describe 'Awesome API' do

  it 'does a HTTP API request with a preconfigured client', tags: [:demo, :http, :request] do

    http 'dummy_api' do
      method 'GET'
      path 'employee/1'
      auth 'basic_auth'

      header 'X-Custom', 'Some Value'
      header 'X-Custom2', 'Another Value'

      param 'foo', 'bar'
    end

    expect 'the response code to be 200' do
      response.code.should_be '200'
    end

    expect 'the ID to be 1' do
      response.json.data.id.should_be 1
    end

    puts
    puts request.pretty
    puts
    puts response.pretty
    puts
  end

  it 'does a HTTP API request with dynamic client', tags: [:demo, :http, :request] do

    https 'dummy.restapiexample.com/api/v1/' do
      method 'GET'
      path 'employee/1'
    end

    expect 'the response code to be 200' do
      response.code.should_be '200'
    end

    expect 'the ID to be 1' do
      response.json.data.id.should_be 1
    end

  end
end