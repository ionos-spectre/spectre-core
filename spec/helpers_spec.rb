require 'spectre/helpers'

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

  it 'trims a long string' do
    content = 'This is a long text'

    trimmed = content.trim 10

    expect(trimmed).to eq('This is...')
  end

  it 'converts a OpenStruct into json string' do
    h = { foo: 'bar', bla: { key: 'val' } }

    expect(h.to_json).to eq('{"foo":"bar","bla":{"key":"val"}}')
  end

  it 'generates a uuid' do
    id = uuid 10

    expect(id.length).to eq(10)
    expect(uuid.length).to eq(5)
    expect(uuid(32).length).to eq(32)
    expect(uuid(50).length).to eq(32)
  end
end