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

  it 'group some processes' do
    group 'first one' do
      info 'do something'
    end

    group 'second one' do
      info 'do another thing'
    end
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

  it 'should fail within an expecation', tags: [:fail] do
    info 'another thing'

    expect 'to succeed' do
      fail_with 'bad thing'
    end
  end

  it 'should fail directly', tags: [:fail] do
    info 'another thing'

    fail_with 'bad thing'
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

describe 'Expectations' do
  it 'should match "be" positively', tags: [:expectation, :be] do
    some_object = OpenStruct.new(foo: 'bar')

    some_object.foo.should be 'bar'
    some_object.foo.should be 'bar'.or 'baz'

    # Fail
    some_object.foo.should be 'blubber'
  end

  it 'should match "be" negatively', tags: [:expectation, :be] do
    some_object = OpenStruct.new(foo: 'bar')

    some_object.foo.should_not be 'baz'
    some_object.foo.should_not be 'bar'.or 'blubber'
    some_object.foo.should_not be 'bla'.or 'blubber'

    # Fail
    some_object.foo.should_not be 'bar'
  end

  it 'should match "contain" positively', tags: [:expectation, :contain] do
    some_list = [1, 2, 3, 'foo']

    some_list.should contain 'foo'
    some_list.should contain 2.or 'baz'
    some_list.should contain 2.and 'foo'

    # Fail
    some_list.should contain 'bar'
  end

  it 'should match "contain" negatively', tags: [:expectation, :contain] do
    some_list = [1, 2, 3, 'foo']

    some_list.should_not contain 'baz'
    some_list.should_not contain 'bar'.or 'blubber'
    some_list.should_not contain 'bla'.and 6

    # Fail
    some_list.should_not contain 3
  end

  it 'should match "match" positively', tags: [:expectation, :match] do
    some_text = "This is foo"

    some_text.should match /^This is/
    some_text.should match /bar/.or /foo/

    # Fail
    some_text.should match /bar/.and /foo/
  end

  it 'should match "match" negatively', tags: [:expectation, :match] do
    some_text = "This is foo"

    some_text.should_not match /^That is/
    some_text.should_not match /bar/.or /foo/

    # Fail
    some_text.should_not match /bar/.and /foo/
  end

  it 'should match "be_empty" positively', tags: [:expectation, :be_empty] do
    empty_list = []

    empty_list.should be_empty

    # Fail
    some_list = [1, 2, 3, 'foo']
    some_list.should be_empty
  end

  it 'should match "be_empty" negatively', tags: [:expectation, :be_empty] do
    some_list = [1, 2, 3, 'foo']
    some_list.should_not be_empty

    # Fail
    empty_list = []
    empty_list.should_not be_empty
  end
end
