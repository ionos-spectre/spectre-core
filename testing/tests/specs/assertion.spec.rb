describe 'spectre/assertion' do
  it 'expects code to pass', tags: [:assertion, :core] do
    expect 'two strings to be equal' do
      'foo'.should_be 'foo'
    end

    expect 'two strings not to be equal' do
      'foo'.should_not_be 'bar'
    end
  end

  it 'compares two unequal strings and fails', tags: [:assertion, :equal, :core, :fail] do
    expect 'two strings not to be equal' do
      'foo'.should_not_be 'foo'
    end
  end

  it 'compares two equal strings and fails', tags: [:assertion, :equal, :core, :fail] do
    expect 'two strings to be equal' do
      'foo'.should_be 'bar'
    end
  end

  it 'looks up a string which contains another one but it fails', tags: [:assertion, :contain, :core, :fail] do
    expect "a text to contain 'foo'" do
      "this is a pretty long text, that contains bar".should_contain 'foo'
    end
  end

  it 'observes if an item is in a list and fails', tags: [:assertion, :contain, :array, :core, :fail] do
    expect 'a specific item in a list' do
      ['foo', 'bla'].should_contain 'bar'
    end
  end

  it 'observes a process which succeeds', tags: [:assertion, :observe, :core] do
    observe 'some process' do
      log 'do some stuff'
    end

    expect 'the process to be successful' do
      success?.should_be true
    end
  end

  it 'observes a process which fails', tags: [:assertion, :observe, :core] do
    observe 'some process' do
      raise 'There was a problem'
    end

    expect 'the process to fail' do
      success?.should_be false
    end
  end
end