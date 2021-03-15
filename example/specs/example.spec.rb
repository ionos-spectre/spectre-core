describe 'Awesome API' do

  setup do
    log 'do something to setup it all up'
  end

  teardown do
    log 'do something to bring it all down'
  end

  before do
    log 'do some things before the spec'
  end

  after do
    log 'do some things afterwards'
  end

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

    log 'get next data'

    http 'dummy_api' do
      method 'GET'
      path "employee/#{response.json.data.id + 1}"
      auth 'basic_auth'
    end
  end

  it 'does a HTTP API request with dynamic client', tags: [:demo, :http, :request] do

    https 'dummy.restapiexample.com/api/v1/' do
      method 'GET'
      basic_auth 'dummy', 'foobar'
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