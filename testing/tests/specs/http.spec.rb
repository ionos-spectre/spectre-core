describe 'spectre/http' do
  it 'gets resources from rest api', tags: [:http, :get] do
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

  it 'post a new resource', tags: [:http, :post] do
    http 'localhost:4567/api/v1/' do
      method 'POST'
      path 'echo'
      json({
        "id": 2,
        "desc": "Do some more stuff"
      })
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'the id to be 2' do
      response.json.id.should_be 2
    end
  end

  it 'updates a resource with preconfigured http client', tags: [:http, :put] do
    info 'get the first todo'

    http 'web_api' do
      method 'GET'
      path "todos/1"
      ensure_success!
    end

    todo = response.json

    info 'update the first todo'

    todo.done = true

    http 'web_api' do
      method 'PUT'
      path 'echo'
      json todo
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'the id to be 1' do
      response.json.done.should_be true
    end
  end

  it 'directly uses a response to do another request', tags: [:http, :post] do
    info 'get all todos'

    http 'web_api' do
      method 'GET'
      path 'todos'
      ensure_success!
    end

    info 'echo the first todo'

    http 'web_api' do
      method 'POST'
      path 'echo'
      json response.json.first
    end

    expect 'the data to be the first todo' do
      response.json.id.should_be 1
    end
  end

  it 'adds new resources to a list', tags: [:http, :put] do
    http 'localhost:4567/api/v1/' do
      method 'GET'
      path 'todos'
    end

    response.json.append({
      "id": 5,
      "desc": "A new todo item",
      "done": false,
    })

    http 'localhost:4567/api/v1/' do
      method 'PUT'
      path 'echo'
      json response.json
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'the item to be in the list' do
      fail_with response.json if not response.json.any? { |x| x.id == 5 }
    end
  end
end
