describe 'spectre/http' do
  it 'gets an echo', tags: [:curl, :get, :deps] do
    curl 'localhost:4567/api/v1/' do
      method 'POST'
      path 'echo'
      body 'Hello World!'
    end

    expect 'the response code to be 200' do
      curl_response.code.should_be 200
    end

    expect 'two items' do
      curl_response.body.should_be 'Hello World!'
    end
  end
end
