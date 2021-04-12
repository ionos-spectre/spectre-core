require 'sinatra'
require 'json'

ENTRIES = [
  { id: 1, desc: 'Spook around', done: true },
  { id: 2, desc: 'Scare some people', done: false },
]

get '/health' do
  status 200
end

get '/todos' do
  status 200
  ENTRIES.to_json
end

get '/todos/:id' do |id|
  todo = ENTRIES.first { |x| x[:id] == id }

  if not todo
    status 404
    return
  end

  status 200
  todo.to_json
end

post '/hello' do
  status 200
  mime_type 'application/json'

  return {
    message: 'Hello client!'
  }.to_json
end

post '/auth/tokens' do

end