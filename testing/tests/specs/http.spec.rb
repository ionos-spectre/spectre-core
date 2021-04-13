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
      path 'todos'
      json({
        "desc": "Do some more stuff"
      })
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'two items' do
      response.json.count.should_be 2
    end
  end
end
