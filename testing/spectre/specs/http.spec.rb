describe 'spectre/http' do
  it 'gets resources from rest api', tags: [:http, :get, :deps] do
    http 'localhost:4567/api/v1/' do
      method 'GET'
      path 'todos'
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'two items' do
      response.json.count.should_be 2
    end
  end

  it 'post a new resource', tags: [:http, :post, :deps] do
    http 'localhost:4567/api/v1/' do
      method 'POST'
      path 'echo'
      json({
        "id": 2,
        "desc": "Do some more stuff",
      })
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'the id to be 2' do
      fail_with response.json.id unless response.json.id == 2
    end
  end

  it 'updates a resource with preconfigured http client', tags: [:http, :put, :deps] do
    info 'get the first todo'

    http 'web_api' do
      method 'GET'
      path "todos/1"
      ensure_success!
    end

    todo = response.json

    info 'update the first todo'

    todo.desc = 'Do some updated stuff'
    todo.done = true

    http 'web_api' do
      method 'PUT'
      path 'todos'
      json todo
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'the id to be 1' do
      response.json.id.should_be 1
    end
  end

  it 'does long polling successfully', tags: [:http, :get, :longpolling] do
    http 'web_api' do
      method 'GET'
      path 'longpoll'
      timeout 10
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'a message' do
      response.json.message.should_be 'Hello there!'
    end
  end
end
