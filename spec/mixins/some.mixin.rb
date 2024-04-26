Spectre.mixin 'run some mixin' do
  info 'some info from within a mixin'
end

Spectre.mixin 'run some mixin with list parameters' do |a, b|
  a.should be 'foo'
  b.should be 'bar'
end

Spectre.mixin 'run some mixin with hash parameters' do |param|
  param.foo.should be 'bar'
end

Spectre.mixin 'run some mixin with bag access' do |param|
  bag.foo.should be 'bar'
end
