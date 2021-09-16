require 'sinatra'
require 'json'

ENTRIES = [
  { id: 1, desc: 'Spook around', done: true },
  { id: 2, desc: 'Scare some people', done: false },
]

post '/api/v1/echo' do
  status 200
  request.body.read
end

put '/api/v1/echo' do
  status 200
  request.body.read
end

get '/api/v1/bad' do
  status 200
  request.body.read
end

get '/api/v1/health' do
  status 200
end

get '/api/v1/todos' do
  status 200
  ENTRIES.to_json
end

delete '/api/v1/todos' do
  status 200
  ENTRIES.to_json
end

post '/api/v1/todos' do
  status 200
  todo = JSON.parse(request.body.read, symbolize_names: true)
  todo[:id] = ENTRIES.count
  ENTRIES.append todo
  todo.to_json
end

put '/api/v1/todos' do
  status 200
  request.body.read
end

get '/api/v1/todos/:id' do |id|
  todo = ENTRIES.first { |x| x[:id] == id }

  if not todo
    status 404
    return
  end

  status 200
  todo.to_json
end

put '/api/v1/todos/:id' do
  status 200
  request.body.read
end

post '/api/v1/hello' do
  status 200
  mime_type 'application/json'

  return {
    message: 'Hello client!',
  }.to_json
end

post 'keystone/main/v3/auth/tokens' do
  status 200
  headers['X-Subject-Token'] = 'gAAAAABgdAf85Nbthisissomefaketokendontworry_TeTh3CIF0s49m-49d6zUjV-gZjHzeThF1234576olKikjhgfdsFYq-lL-L4n4kjrh23498ywkfjdn2908452034h5w0f8y25b2945ytg2016s'
  {
    "token": {
      "methods": [
        "password",
      ],
      "user": {
        "domain": {
          "id": "de4da3bba13648e9a29dd21af6ab0f09",
          "name": "waas_qa",
        },
        "id": "b7461d3f63be464bb6fdb89bf0f7fe24",
        "name": "WhicQA_Admin",
        "password_expires_at": null,
      },
      "audit_ids": [
        "vLdvkBwOSUCpR8daCRfDxg",
      ],
      "expires_at": "2021-04-12T16:42:36.000000Z",
      "issued_at": "2021-04-12T08:42:36.000000Z",
      "project": {
        "domain": {
          "id": "de4da3bba13648e9a29dd21af6ab0f09",
          "name": "waas_qa",
        },
        "id": "d3f3c9f9243f4f58924370d0a50f9242",
        "name": "WhicQA",
      },
      "is_domain": false,
      "roles": [
        {
          "id": "9e1b7677810d44b9b5f85aa9a7af7257",
          "name": "member",
        },
        {
          "id": "65033c3605454826bd659b2cde3d2d67",
          "name": "admin",
        },
        {
          "id": "92723567682a4786bd7266f21b933296",
          "name": "reader",
        },
      ],
    },
  }.to_json
end