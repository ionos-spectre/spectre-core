require_relative '../lib/spectre'

RSpec.describe 'Output' do
  it 'should have a pretty output' do
    runs = Spectre
      .setup({
        'specs' => [],
        'tags' => [],
        'formatter' => 'Spectre::ConsoleFormatter',
        'stdout' => $stdout,
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
    expect(@runs.count).to eq(8)
  end

  it 'runs: setup' do
    run = @runs[0]

    expect(run.parent.desc).to eq('General')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    _timestamp, _severity, _progname, message = run.logs.first

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

    _, severity, progname, message = run.logs.first

    expect(progname).to eq('spectre')
    expect(severity).to eq('INFO')
    expect(message).to eq('some info')
  end

  it 'runs: should run with an error' do
    run = @runs[3]

    expect(run.error).to be_kind_of(RuntimeError)
    expect(run.error.message).to eq('Oops!')
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    _, severity, progname, message = run.logs.first

    expect(progname).to eq('spectre')
    expect(severity).to eq('FATAL')
    expect(message).to start_with('Oops!')
  end

  it 'runs: should run with a failure' do
    run = @runs[4]

    expect(run.error).to eq(nil)

    expect(run.failure).to be_kind_of(Spectre::Expectation::ExpectationFailure)
    expect(run.failure.message).to eq('fail for fun')
    expect(run.failure.desc).to eq(nil)

    expect(run.logs.count).to eq(1)

    _, severity, progname, message = run.logs.first

    expect(progname).to eq('spectre')
    expect(severity).to eq('ERROR')
    expect(message).to eq('fail for fun - in specs/general.spec.rb:29')
  end

  it 'runs: should run with an expectation failure' do
    run = @runs[5]

    expect(run.error).to eq(nil)

    expect(run.failure).to be_kind_of(Spectre::Expectation::ExpectationFailure)
    expect(run.failure.message).to eq('expected to succeed, but it failed with "fail for fun"')
    expect(run.failure.desc).to eq(nil)

    expect(run.logs.count).to eq(1)

    _, severity, progname, message = run.logs.first

    expect(progname).to eq('spectre')
    expect(severity).to eq('ERROR')
    expect(message).to eq('expected to succeed, but it failed with "fail for fun"')
  end

  it 'runs: should run with multiple data' do
    expect(@runs[6].parent.name).to eq('general-6.0')
    expect(@runs[7].parent.name).to eq('general-6.1')
  end
end
