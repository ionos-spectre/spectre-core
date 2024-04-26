Spectre.describe 'Mixin' do
  it 'executes a mixin', tags: [:success] do
    also 'run some mixin'
  end

  it 'executes a mixin with list parameters', tags: [:success] do
    also 'run some mixin with list parameters', with: ['foo', 'bar']
  end

  it 'executes a mixin with hash parameters', tags: [:success] do
    also 'run some mixin with hash parameters', with: { foo: 'bar' }
  end

  it 'uses a bag value within a mixin', tags: [:success] do
    bag.foo = 'bar'
    also 'run some mixin with bag access'
  end
end
