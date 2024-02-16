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

  it 'runs: evaluates within an expect block' do
    run = @runs[0]

    expect(run.parent.parent.desc).to eq('Expectation')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(2)

    expect(run.logs[0][3]).to eq('expect the_truth to be 42 - ok')
    expect(run.logs[1][3]).to eq('this is a message')
  end

  it 'runs: evaluates "should_not be"' do
    run = @runs[1]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expect the_truth not to be 666 - ok')
  end

  it 'runs: evaluates "should be"' do
    run = @runs[2]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expect the_truth.value to be 42 - ok')
  end

  it 'evaluates "should contain and" with a list' do
    run = @runs[3]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expect the_truth_list to contain 42 and 86 - ok')
  end

  it 'evaluates "should be or" with a single value' do
    run = @runs[4]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expect the_truth to be 42 or 86 - ok')
  end

  it 'evaluates "should contain or" with a list' do
    run = @runs[5]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expect the_truth_list to contain 42 or 86 - ok')
  end

  it 'evaluate "should match"' do
    run = @runs[6]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expect the_truth to match /42/ - ok')
  end

  it 'runs: fails "should be"' do
    run = @runs[7]

    expect(run.error).to eq(nil)

    expect(run.failure).to be_kind_of(Spectre::Expectation::ExpectationFailure)
    expect(run.failure.message).to eq('expect the_truth to be 42')
    expect(run.failure.desc).to eq('got 666')

    expect(run.logs.count).to eq(1)

    expect(run.logs.first[3]).to eq('expect the_truth to be 42 - in specs/expectation.spec.rb:53')
  end
end
