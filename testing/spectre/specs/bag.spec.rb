describe 'spectre/bag' do
  setup do
    expect 'the bag to be empty' do
      bag.to_h.empty?.should_be true
    end

    bag.setup = 'done'
  end

  it 'should be empty at start', tags: [:bag] do
    bag.foo = 'bar'

    expect 'the bag not to be empty' do
      bag.to_h.empty?.should_be false
    end

    expect 'the variable foo set to bar' do
      bag.foo.should_be 'bar'
    end
  end

  it 'set a variable in setup', tags: [:bag] do
    expect 'the setup to be done' do
      bag.setup.should_be 'done'
    end
  end
end
