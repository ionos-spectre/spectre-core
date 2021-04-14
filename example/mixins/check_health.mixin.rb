mixin 'check health' do |url|
  http url do
    method 'GET'
  end

  expect 'the response code to be 200' do
    response.code.should_be 200
  end
end