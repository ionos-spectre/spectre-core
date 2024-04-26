Spectre.describe 'Bag' do
  setup do
    info 'set some data for this context'
    bag.setup_data = 'bla'
  end

  teardown do
    info 'cleanup some data for this context'
    bag.setup_data.should be 'bla'
  end

  before do
    info 'set some data before each run'
    bag.data = 'foo'
  end

  after do
    expect 'the bag to be available in after block' do
      fail_with 'bag is empty' if bag.data.nil? or bag.data.empty?
    end
  end

  it 'uses bag in definition and spec' do
    bag.setup_data.should be 'bla'
    bag.data.should be 'foo'

    bag.data = 'baz'
  end

  it 'does reset bag on every spec run' do
    bag.data.should be 'foo'
  end
end
