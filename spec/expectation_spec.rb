RSpec.describe 'Expectation' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['expectation-*'],
        'tags' => [],
        'stdout' => StringIO.new,
      })
      .run
  end

  it 'evaluates within an expect block' do
    run = @runs.find { |x| x.parent.desc == 'evaluates within an expect block' }

    expect(run.parent.parent.desc).to eq('Expectation')
    expect(run.logs.count).to eq(2)

    expect(run.logs[0][3]).to eq('expect the_truth to be 42 - ok')
    expect(run.logs[1][3]).to eq('this is a message')
  end

  it 'fails within an expect block' do
    run = @runs.find { |x| x.parent.desc == 'fails within an expect block' }

    failure = run.failures.first

    expect(failure.message).to eq('expected to succeed, but it failed with ' \
                                  '"expected the_truth to be 42, but got 666"')

    expect(failure.inner.desc).to eq('got 666')

    expect(run.logs[0][3]).to start_with('expected to succeed, but it failed with ' \
                                         '"expected the_truth to be 42, but got 666" ')
    expect(run.logs[0][3]).to match(%r{- in specs/expectation.spec.rb:\d+})
  end

  it 'evaluates "should_not be"' do
    run = @runs.find { |x| x.parent.desc == 'evaluates "should_not be"' }

    expect(run.logs.count).to eq(1)
    expect(run.logs.first[3]).to eq('expect the_truth not to be 666 - ok')
  end

  it 'evaluates "should be"' do
    run = @runs.find { |x| x.parent.desc == 'evaluates "should be"' }

    expect(run.logs.count).to eq(1)
    expect(run.logs.first[3]).to eq('expect the_truth.value to be 42 - ok')
  end

  it 'evaluates "should contain and" with a list' do
    run = @runs.find { |x| x.parent.desc == 'evaluates "should contain and" with a list' }

    expect(run.logs.count).to eq(1)
    expect(run.logs.first[3]).to eq('expect the_truth_list to contain 42 and 86 - ok')
  end

  it 'evaluates "should be or" with a single value' do
    run = @runs.find { |x| x.parent.desc == 'evaluates "should be or" with a single value' }

    expect(run.logs.count).to eq(1)
    expect(run.logs.first[3]).to eq('expect the_truth to be 42 or 86 - ok')
  end

  it 'evaluates "should contain or" with a list' do
    run = @runs.find { |x| x.parent.desc == 'evaluates "should contain or" with a list' }

    expect(run.logs.count).to eq(1)
    expect(run.logs.first[3]).to eq('expect the_truth_list to contain 42 or 86 - ok')
  end

  it 'evaluate "should match"' do
    run = @runs.find { |x| x.parent.desc == 'evaluate "should match"' }

    expect(run.logs.count).to eq(1)
    expect(run.logs.first[3]).to eq('expect the_truth to match /truth.*\\s\\d+$/ - ok')
  end

  it 'fails "should be"' do
    run = @runs.find { |x| x.parent.desc == 'fails "should be"' }

    failure = run.failures.first

    expect(failure.message).to eq('expected the_truth to be 42, but got 666')
    expect(failure.inner.desc).to eq('got 666')

    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expected the_truth to be 42, but got 666 - in specs/expectation.spec.rb:62')
  end
end
