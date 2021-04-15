mixin 'some routine' do
  log 'do some stuff wihtin mixin'
end

mixin 'check some value' do |value, check|
  expect 'the two values to be equal' do
    value.should_be check
  end
end