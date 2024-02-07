require_relative '../lib/spectre'

RSpec.describe 'Output' do
  it 'should have a pretty output' do
    runs = Spectre
      .setup({
        'specs' => [],
        'tags' => [],
        'formatter' => 'Spectre::ConsoleFormatter',
        'stdout' => $stdout
        # 'debug' => true,
      })
      .run

    Spectre.report(runs)
  end
end

RSpec.describe 'General' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['general-*'],
        'stdout' => StringIO.new,
      })
      .run
  end

  it 'should run' do
    expect(Spectre::CONTEXTS.select { |x| x.desc == 'General' }.count).to eq(1)
    expect(@runs.count).to eq(6)
  end

  it 'runs: setup' do
    run = @runs[0]

    expect(run.parent.desc).to eq('General')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, _name, _level, message, _status, _desc = run.logs.first

    expect(timestamp).to be_kind_of(DateTime)
    expect(message).to eq('do some setting up')
  end

  it 'runs: should run successfully' do
    run = @runs[1]

    expect(run.parent.parent.desc).to eq('General')
    expect(run.parent.desc).to eq('should run successfully')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(3)
    expect(run.parent.desc).to eq('should run successfully')

    timestamp, name, level, message, status, desc = run.logs.first

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:info)
    expect(message).to eq('some info')
    expect(status).to eq(nil)
    expect(desc).to eq(nil)
  end

  it 'runs: should run with an error' do
    run = @runs[3]

    expect(run.error).to be_kind_of(RuntimeError)
    expect(run.error.message).to eq('Oops!')
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs.first

    expect(name).to eq('spectre')
    expect(level).to eq(:fatal)
    expect(message).to eq('Oops!')
    expect(status).to eq(:error)
    expect(desc).to eq('RuntimeError')
  end

  it 'runs: should run with a failure' do
    run = @runs[4]

    expect(run.error).to eq(nil)

    expect(run.failure).to be_kind_of(Spectre::Expectation::ExpectationFailure)
    expect(run.failure.message).to eq('fail for fun')
    expect(run.failure.desc).to eq(nil)

    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc, exception = run.logs.first

    expect(name).to eq('spectre')
    expect(level).to eq(:error)
    expect(message).to eq('fail for fun')
    expect(status).to eq(:failed)
    expect(desc).to eq(nil)
    expect(exception).to be(nil)
  end

  it 'runs: should run with an expectation failure' do
    run = @runs[5]

    expect(run.error).to eq(nil)

    expect(run.failure).to be_kind_of(Spectre::Expectation::ExpectationFailure)
    expect(run.failure.message).to eq('expected to succeed, but it failed with "fail for fun"')
    expect(run.failure.desc).to eq(nil)

    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc, exception = run.logs.first

    expect(name).to eq('spectre')
    expect(level).to eq(:error)
    expect(message).to eq('expect to succeed')
    expect(status).to eq(:failed)
    expect(desc).to eq(nil)
    expect(exception).to be_kind_of(Spectre::Expectation::ExpectationFailure)
    expect(exception.message).to eq('expected to succeed, but it failed with "fail for fun"')
  end
end
