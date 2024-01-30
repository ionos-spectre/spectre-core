# Expose spectre methods
%i{env describe bag mixin resources}.each do |method|
  define_method(method) do |*args, &block|
    Spectre.send(method, *args, &block)
  end
end


%i{debug info warn}.each do |method|
  define_method(method) do |*args, &block|
    Spectre.logger.send(method, *args, &block)
  end
end

%i{be be_empty contain match}.each do |method|
  define_method(method) do |*args, &block|
    Spectre::Expectation.send(method, *args, &block)
  end
end

Spectre.describe 'General' do
  setup do
    info 'do some setting up'
  end

  it 'should run successfully' do
    info 'some info'
    info "this is a\nmultiline message"
  end
end

Spectre.describe 'General' do
  it 'another general run defined in different block' do
    info 'some info'
  end
end

Spectre.describe 'Expectation' do
  it 'evaluates within an expect block' do
    the_truth = 42

    expect 'to succeed' do
      the_truth.should be 42
    end
  end

  it 'evaluates "should_not be"' do
    the_truth = 42

    the_truth.should_not be 666
  end

  it 'evaluates "should be"' do
    the_truth = 42

    the_truth.should be 42
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
end

Spectre.describe 'Context' do
  context 'within a new context' do
    it 'should run within a child context' do
      info 'some info from wihtin a context'
    end
  end
end

Spectre.describe 'Tag' do
  it 'should run with the tag', tags: [:tagged, :another_tag] do
    info 'do something tagged'
  end

  it 'should also run with tags', tags: [:tagged] do
    info 'do something tagged'
  end

  it 'should not run with this tag', tags: [:tagged, :special_tag] do
    info 'do something tagged'
  end
  
  it 'has no tags' do
    info 'do something without any tags'
  end
end

Spectre.describe 'Mixin' do
  it 'executes a mixin' do
    also 'run some mixin'
  end

  it 'executes a mixin with list parameters' do
    also 'run some mixin with list parameters', with: ['foo', 'bar']
  end

  it 'executes a mixin with hash parameters' do
    also 'run some mixin with hash parameters', with: { foo: 'bar' }
  end
end

Spectre.describe 'Environment' do
  it 'should access a variable from the environment' do
    env.foo.should be 'bar'
  end

  it 'should access a  variable from a partial environment' do
    env.some_secret.should be 'some_secret_value'
  end

  it 'should use env variable in spec definition', with: [env.foo] do |data|
    data.should be 'bar'
  end
end
