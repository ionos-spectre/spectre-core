describe 'Some Subject' do
  setup do
    log 'do some setup stuff once'
  end

  teardown do
    log 'do some teardown stuff once'
  end

  before do
    log 'do some stuff before each run'

    bag.foo = 'bar'
  end

  after do
    log 'do some stuff after each run'
  end

  it 'does some stuff', tags: [:test, :dummy] do
    log 'do some stuff'

    property 'foo', 'bar'

    sleep 0.1

    expect 'some stuff' do
      42.should_be 42
    end

    expect 'some stuff to break' do
      fail_with 'Oops!'
    end
  end
end