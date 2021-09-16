describe 'spectre/http' do
  it 'gets an echo', tags: [:curl, :deps] do
    curl 'localhost:4567/api/v1/' do
      method 'POST'
      path 'echo'
      body 'Hello World!'
      header 'authorization', 'blablubb'
    end

    expect 'the response code to be 200' do
      curl_response.code.should_be 200
    end

    expect 'two items' do
      curl_response.body.should_be 'Hello World!'
    end
  end

  it 'gets an echo with json body', tags: [:curl, :deps, :secure] do
    curl 'localhost:4567/api/v1/' do
      method 'POST'
      path 'echo'
      json({
        "username": "dummy",
        "password": "this should never be logged"
      })
      header 'authorization', 'blablubb'
    end

    expect 'the response code to be 200' do
      curl_response.code.should_be 200
    end

    expect 'two items' do
      curl_response.json.username.should_be 'dummy'
    end
  end
end
