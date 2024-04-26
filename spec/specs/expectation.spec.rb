%i{be be_empty contain match}.each do |method|
  define_method(method) do |*args, &block|
    Spectre::Expectation.send(method, *args, &block)
  end
end

Spectre.describe 'Expectation' do
  it 'evaluates within an expect block' do
    the_truth = 42

    expect 'to succeed' do
      the_truth.should be 42
    end

    info 'this is a message'
  end

  it 'fails within an expect block' do
    the_truth = 666

    expect 'to succeed' do
      the_truth.should be 42
    end

    info 'this is a message'
  end

  it 'evaluates "should_not be"' do
    the_truth = 42

    the_truth.should_not be 666
  end

  it 'evaluates "should be"' do
    the_truth = OpenStruct.new(value: 42)

    the_truth.value.should be 42
  end

  it 'evaluates "should contain and" with a list' do
    the_truth_list = [42, 666, 86]
    the_truth_list.should contain 42.and 86
  end

  it 'evaluates "should be or" with a single value' do
    the_truth = 42
    the_truth.should be 42.or 86
  end

  it 'evaluates "should contain or" with a list' do
    the_truth_list = [42, 666]
    the_truth_list.should contain 42.or 86
  end

  it 'evaluate "should match"' do
    the_truth = 'the truth is 42'
    the_truth.should match /42/
  end

  it 'fails "should be"' do
    the_truth = 666

    the_truth.should be 42
  end
end
