RSpec.describe Spectre::Helpers do
  it 'defaults OpenStructs' do
    o = OpenStruct.new({foo: 'bar', some_bool: false})

    o.default_to! bar: 'foo',
                  foo: 'foo',
                  some_bool: true

    expect(o.bar).to eq('foo')
    expect(o.foo).to eq('bar')
    expect(o.some_bool).to eq(false)
  end

  it 'defaults OpenStructs with given hash' do
    o = OpenStruct.new({foo: 'bar'})

    o.default_to!({
      bar: 'foo',
      foo: 'foo',
      some_bool: true
    })

    expect(o.bar).to eq('foo')
    expect(o.foo).to eq('bar')
    expect(o.some_bool).to eq(true)
  end
end
