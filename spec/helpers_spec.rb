RSpec.describe Spectre::Helpers do
  it 'defaults OpenStructs' do
    o = OpenStruct.new({foo: 'bar'})

    o.default_to! bar: 'foo',
                  foo: 'foo'

    expect(o.bar).to eq('foo')
    expect(o.foo).to eq('bar')
  end

  it 'defaults OpenStructs with given hash' do
    o = OpenStruct.new({foo: 'bar'})

    o.default_to!({
      bar: 'foo',
      foo: 'foo'
    })

    expect(o.bar).to eq('foo')
    expect(o.foo).to eq('bar')
  end
end
