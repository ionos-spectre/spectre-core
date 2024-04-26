Spectre.describe 'General' do
  setup do
    info 'do some setting up'
    @foo = 'bar'
  end

  it 'should run successfully', tags: [:success] do
    info 'some info'
    info "this is a\nmultiline message"
    debug 'this is a debug message'
  end

  it 'accesses a variable from setup', tags: [:fail] do
    @foo.should be 'bar'
    @bar = 'baz'
  end

  it 'does not access a variable from previous spec', tags: [:success] do
    @bar.should be nil
  end
end

Spectre.describe 'General' do
  it 'another general run defined in different block', tags: [:success] do
    info 'some info'
  end

  it 'should run with an error', tags: [:error] do
    raise 'Oops!'
  end

  it 'should run with a failure', tags: [:fail] do
    fail_with 'fail for fun'

    info 'some info, which will never be logged'
  end

  it 'should run with an expectation failure', tags: [:fail] do
    expect 'to succeed' do
      fail_with 'fail for fun'
    end

    info 'some info, which will never be logged'
  end

  it 'should run with multiple simple data', tags: [:success], with: ['foo', 'bar'] do |data|
    info "running with data: #{data}"
    data.should be 'foo'.or 'bar'
  end

  it 'should run with multiple complex data', tags: [:success], with: [{foo: 'bar'}, {foo: 'baz'}] do |data|
    info "running with data: #{data.foo}"

    data.foo.should be 'bar'.or 'baz'
  end

  it 'observes a process', tags: [:success] do |_data|
    observe 'some expectation' do
      666.should be 42
    end

    info 'continues to run'
  end
end
