class TestError < Exception
end

describe 'Test' do
  setup do
    info 'do some setting up'
    bag.foo = 'bar'
  end

  teardown do
    info 'do some tearing down'
  end

  before do
    info 'do something before'
  end

  after do
    info 'do something after'
  end

  it 'should do something', tags: [:tagged] do
    info 'do something'

    debug 'a debug message'

    expect 'to run successfully' do
    end

    expect 'to run with a short delay' do
      sleep 0.5
    end

    sleep 0.3
  end

  it 'reads env variables' do
    info "env.foo = #{env.foo}"
  end

  it 'accesses the bag' do
    info "bag.foo = #{bag.foo}"
  end

  it 'executes with multiple data', with: ['foo', 'bar'] do |data|
    info "running with '#{data}'"
  end

  it 'should do another thing', tags: [:fail] do
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
      raise TestError.new('Oops!')
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
    raise TestError.new('Oops!')
  end

  it 'should expect something and crash' do
    expect 'something' do
      raise TestError.new('Oops!')
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

describe 'HTTP' do
  it 'should do a request', tags: [:http] do
    http 'dummy' do
    end

    expect 'to get a 200' do
      fail unless response.code.equal? 200
    end
  end
end

describe 'Mixins' do
  before do
    @some_var = 42
  end

  it 'should run a mixin' do
    info "the answer is #{@some_var}"
    also 'do additional stuff', with: ['Hello', 'World']
  end
end

describe 'Fatal Setup' do
  setup do
    raise TestError.new('Oops!')
  end

  teardown do
    info 'but this should always run'
  end

  it 'should not run' do
    info 'this should not run'
  end
end
