Spectre.describe 'Mixin' do
  it 'executes a mixin' do
    also 'run some mixin'
  end

  it 'executes a mixin with list parameters' do
    also 'run some mixin with list parameters', with: ['foo', 'bar']
  end

  it 'executes a mixin with hash parameters' do
    also 'run some mixin with hash parameters', with: { foo: 'bar' }
  end

  it 'uses a bag value within a mixin' do
    bag.foo = 'bar'
    also 'run some mixin with bag access'
  end
end
