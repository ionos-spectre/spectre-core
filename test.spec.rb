describe 'Test' do
  before do
    info 'do something before'
  end

  after do
    info 'do something after'
  end

  it 'should do something', tags: [:tagged] do
    info 'do something'

    expect 'to run successfully' do
    end
  end

  it 'reads env variables' do
    info "env.foo = #{env.foo}"
  end

  it 'executes with multiple data', with: ['foo', 'bar'] do |data|
    info "running with '#{data}'"
  end

  it 'should do another thing' do
    info 'another thing'

    expect 'to fail' do
      fail_with 'Oops!'
    end
  end

  context 'with a sub context' do
    it 'should do also something' do
      info 'also do things'
    end

    it 'fails in a sub context' do
      raise 'Oops!'
    end
  end
end

describe 'Another Test' do
  after do
    info 'cleanup the mess'
  end

  it 'should do something' do
    info 'do something'

    info "log some\nmultiline message"

    expect 'to run successfully' do
    end
  end

  it 'should actually crash horribly' do
    info 'working at the moment'
    raise 'Oops!'
  end

  it 'should expect something and crash' do
    expect 'something' do
      raise 'Oops!'
    end
  end

  it 'should be skipped' do
    info 'working at the moment'
    raise Interrupt
  end

  it 'should be skipped while expecting' do
    info 'working at the moment'

    expect 'to do do something' do
      raise Interrupt
    end
  end
end
