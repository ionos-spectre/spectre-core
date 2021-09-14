require 'spectre'
require 'spectre/mixin'

RSpec.describe 'spectre/mixin' do
  it 'runs a mixin without parameters' do
    mixin_name = 'do something'

    some_value = nil

    Spectre::Mixin.mixin mixin_name do
      some_value = 'Hello World!'
    end

    Spectre::Mixin.run(mixin_name)

    expect(some_value).to eq('Hello World!')
  end

  it 'runs a mixin with nil parameter' do
    mixin_name = 'do something'

    Spectre::Mixin.mixin mixin_name do |params|
      # expect the parameter to equal an empty OpenStruct, when nil is passed
      expect(params).to eq(OpenStruct.new)
    end

    Spectre::Mixin.run(mixin_name, with: nil)
  end

  it 'runs a mixin with list parameters' do
    mixin_name = 'do something'

    some_value = nil

    Spectre::Mixin.mixin mixin_name do |foo, bar|
      expect(foo).to eq(1)
      expect(bar).to eq(2)
    end

    Spectre::Mixin.run(mixin_name, with: [1, 2])
  end

  it 'runs a mixin with a hash parameter' do
    mixin_name = 'do something'

    some_value = nil

    Spectre::Mixin.mixin mixin_name do |params|
      expect(params).to be_a(OpenStruct)
      expect(params.foo).to eq(1)
      expect(params.bar).to eq(2)
    end

    Spectre::Mixin.run(mixin_name, with: {foo: 1, bar: 2})
  end

  it 'returns a value from a mixin' do
    mixin_name = 'do something'

    Spectre::Mixin.mixin mixin_name do |params|
      'foo'
    end

    value = Spectre::Mixin.run(mixin_name, with: {foo: 1, bar: 2})

    expect(value).to eq('foo')
  end
end