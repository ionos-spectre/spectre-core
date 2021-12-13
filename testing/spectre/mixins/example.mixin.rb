mixin 'some routine' do
  log 'do some stuff wihtin mixin'
end

mixin 'something with params' do |params|
  params.default_to!({
    foo: 'bar',
  })

  expect 'default parameter' do
    params.foo.should_be 'bar'
  end

  log 'do some stuff wihtin mixin'
end

mixin 'check some value' do |value, check|
  expect 'the two values to be equal' do
    value.should_be check
  end
end
