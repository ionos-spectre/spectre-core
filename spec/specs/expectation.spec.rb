Spectre.describe 'Expectation' do
  it 'evaluates within an expect block', tags: [:success] do
    the_truth = 42

    expect 'to succeed' do
      the_truth.should be 42
    end

    info 'this is a message'
  end

  it 'fails within an expect block', tags: [:fail] do
    the_truth = 666

    expect 'to succeed' do
      the_truth.should be 42
    end

    info 'this is a message'
  end

  it 'evaluates "should_not be"', tags: [:success] do
    the_truth = 42

    the_truth.should_not be 666
  end

  it 'evaluates "should be"', tags: [:success] do
    the_truth = OpenStruct.new(value: 42)

    the_truth.value.should be 42
  end

  it 'evaluates "should contain and" with a list', tags: [:success] do
    the_truth_list = [42, 666, 86]
    the_truth_list.should contain 42.and 86
  end

  it 'evaluates "should be or" with a single value', tags: [:success] do
    the_truth = 42
    the_truth.should_be 42.or 86
  end

  it 'evaluates "should be or" with a single value as string', tags: [:success] do
    the_truth = '42'
    the_truth.should be 42.or 86
  end

  it 'evaluates "should contain or" with a list', tags: [:success] do
    the_truth_list = [42, 666]
    the_truth_list.should contain 42.or 86
  end

  it 'evaluate "should match"', tags: [:success] do
    the_truth = 'the truth is 42'
    the_truth.should match /truth.*\s\d+$/
  end

  it 'fails "should be"', tags: [:fail] do
    the_truth = 666

    the_truth.should be 42
  end
  
  it 'continues after fail', tags: [:fail] do
    info 'this message is written'

    assert 'to continue aftes this' do
      fail_with 'an error'
    end

    assert 'to still continue aftes this' do
      fail_with 'an error'
    end

    info 'run failed overall but continued'

    expect 'to stop after this' do
      fail_with 'an error'
    end

    info 'this will never be executed'
  end
end
