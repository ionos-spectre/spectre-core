%i{debug info warn}.each do |method|
  define_method(method) do |*args, &block|
    Spectre.send(method, *args, &block)
  end
end

Spectre.describe 'General' do
  setup do
    info 'do some setting up'
    @foo = 'bar'
  end

  it 'should run successfully' do
    info 'some info'
    info "this is a\nmultiline message"
    debug 'this is a debug message'
  end

  it 'accesses a variable from setup' do
    @foo.should be 'bar'
    @bar = 'baz'
  end

  it 'does not access a variable from previous spec' do
    @bar.should be nil
  end
end

Spectre.describe 'General' do
  it 'another general run defined in different block' do
    info 'some info'
  end

  it 'should run with an error' do
    raise 'Oops!'
  end

  it 'should run with a failure' do
    fail_with 'fail for fun'

    info 'some info, which will never be logged'
  end

  it 'should run with an expectation failure' do
    expect 'to succeed' do
      fail_with 'fail for fun'
    end

    info 'some info, which will never be logged'
  end

  it 'should run with multiple data', with: ['foo', 'bar'] do |data|
    info "running with data: #{data}"
  end
end
