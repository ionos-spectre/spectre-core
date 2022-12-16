require_relative '../lib/spectre/helpers'

RSpec.describe 'spectre/helpers' do
  it 'substitudes placeholders in strings' do
    content = 'Hello #{name}!'

    content = content.with({name: 'World', foo: 'bar'})

    expect(content).to eq('Hello World!')
  end

  it 'reads a file and substitudes placeholders' do
    file_path = 'dummy.txt'

    File.delete(file_path) if File.exist? file_path
    File.write(file_path, 'Hello #{name}!')

    begin
      content = file_path.content with: {name: 'World'}
      expect(content).to eq('Hello World!')
    ensure
      File.delete(file_path)
    end
  end

  it 'checks if a file exists' do
    file_path = 'dummy.txt'

    File.delete(file_path) if File.exist? file_path
    File.write(file_path, 'Hello #{name}!')

    begin
      expect(file_path.exists?).to eq(true)
    ensure
      File.delete(file_path)
    end

    expect('does not exist'.exists?).to eq(false)
  end

  it 'removes an existing file' do
    file_path = 'dummy.txt'

    File.delete(file_path) if File.exist? file_path
    File.write(file_path, 'Hello #{name}!')

    begin
      file_path.remove!
      expect(File.exist? file_path).to eq(false)
    ensure
      File.delete(file_path)if File.exist? file_path
    end
  end

  it 'gets the size of a file' do
    file_path = 'dummy.txt'

    File.delete(file_path) if File.exist? file_path
    file_content = 'Hello World!'
    File.write(file_path, file_content)

    begin
      expect(file_path.file_size).to eq(file_content.size)
    ensure
      File.delete(file_path)
    end
  end

  it 'reads string as json' do
    content = '{"foo": "bar"}'

    json = content.as_json

    expect(json.foo).to eq('bar')
  end

  it 'reads string as date' do
    content = '08.06.1986'

    date = content.as_date

    expect(date.class.name).to eq('DateTime')
    expect(date.day).to eq(8)
    expect(date.month).to eq(6)
    expect(date.year).to eq(1986)
  end

  it 'reads string as timestamp' do
    content = '08.06.1986'

    timestamp = content.as_timestamp

    expect(timestamp).to eq(518572800)
  end

  it 'converts a OpenStruct into json string' do
    h = { foo: 'bar', bla: { key: 'val' } }

    expect(h.to_json).to eq('{"foo":"bar","bla":{"key":"val"}}')
  end

  it 'generates a uuid' do
    id = uuid 10

    expect(id.length).to eq(10)
    expect(uuid.length).to eq(36)
    expect(uuid(32).length).to eq(32)
    expect(uuid(50).length).to eq(50)
  end

  it 'uses jsonpath with string' do
    foo = '{"foo": "bar"}'.pick('$.foo')
    expect(foo).to eq(['bar'])
  end

  it 'uses jsonpath with ostruct' do
    foo = OpenStruct.new({foo: 'bar'}).pick('$.foo')
    expect(foo).to eq(['bar'])
  end

  it 'raises an error when path is empty' do
    expect do
      OpenStruct.new({foo: 'bar'}).pick('')
    end.to raise_error(ArgumentError)
  end

  it 'raises an error when path is nil' do
    expect do
      OpenStruct.new({foo: 'bar'}).pick(nil)
    end.to raise_error(ArgumentError)
  end

  it 'gets the last element of an array' do
    list = [1, 2, 3]
    last_element = list.last
    expect(last_element).to eq(3)
  end

  it 'sets default values in a Hash' do
    h = {foo: 'blubb', num: 123, nothing: nil}

    h.default_to!(
      bar: 'foo',
      foo: 'bar',
      nothing: 'hill',
    )

    h.defaults_to!(
      bar: 'foo',
      foo: 'bar',
    )

    expect(h[:foo]).to eq('blubb')
    expect(h[:bar]).to eq('foo')
    expect(h[:num]).to eq(123)
    expect(h[:nothing]).to eq('hill')
  end

  it 'sets default values in an OpenStruct' do
    o = OpenStruct.new({foo: 'blubb', num: 123})

    o.default_to!(
      bar: 'foo',
      foo: 'bar',
      nothing: 'hill',
    )

    o.defaults_to!(
      bar: 'foo',
      foo: 'bar',
    )

    expect(o.foo).to eq('blubb')
    expect(o.bar).to eq('foo')
    expect(o.num).to eq(123)
    expect(o.nothing).to eq('hill')
  end
end
