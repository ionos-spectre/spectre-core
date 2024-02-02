RSpec.describe 'Expectation' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['expectation-*'],
        'formatter' => 'Spectre::NoopFormatter',
      })
      .run
  end

  it 'runs: evaluates within an expect block' do
    run = @runs[0]

    expect(run.parent.parent.desc).to eq('Expectation')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:debug)
    expect(message).to eq('expect to succeed')
    expect(status).to eq(:ok)
    expect(desc).to eq(nil)
  end

  it 'runs: evaluates "should_not be"' do
    run = @runs[1]

    expect(run.parent.parent.desc).to eq('Expectation')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:debug)
    expect(message).to eq('expect the_truth not to be 666')
    expect(status).to eq(:ok)
    expect(desc).to eq(nil)
  end

  it 'runs: evaluates "should be"' do
    run = @runs[2]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    _, _, _, message, status, _ = run.logs[0]

    expect(message).to eq('expect the_truth to be 42')
    expect(status).to eq(:ok)
  end

  it 'evaluates "should contain and" with a list' do
    run = @runs[3]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    _, _, _, message, status, _ = run.logs[0]

    expect(message).to eq('expect the_truth_list to contain 42 and 86')
    expect(status).to eq(:ok)
  end

  it 'evaluates "should be or" with a single value' do
    run = @runs[4]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    _, _, _, message, status, _ = run.logs[0]

    expect(message).to eq('expect the_truth to be 42 or 86')
    expect(status).to eq(:ok)
  end

  it 'evaluates "should contain or" with a list' do
    run = @runs[5]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    _, _, _, message, status, _ = run.logs[0]

    expect(message).to eq('expect the_truth_list to contain 42 or 86')
    expect(status).to eq(:ok)
  end

  it 'evaluate "should match"' do
    run = @runs[6]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    _, _, _, message, status, _ = run.logs[0]

    expect(message).to eq('expect the_truth to match /42/')
    expect(status).to eq(:ok)
  end
end
