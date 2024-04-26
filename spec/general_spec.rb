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
    expect(@runs.count).to eq(13)
  end

  it 'should have correct names' do
    expect(@runs[0].parent.name).to eq('general') # setup has no number
    expect(@runs[1].parent.name).to eq('general-1')
    expect(@runs[2].parent.name).to eq('general-2')
    expect(@runs[3].parent.name).to eq('general-3')
    expect(@runs[4].parent.name).to eq('general-4')
  end

  it 'gives multi data specs the correct naming' do
    expect(@runs[8].parent.name).to eq('general-8')
    expect(@runs[9].parent.name).to eq('general-9')
  end

  it 'sets up general' do
    run = @runs[0]

    expect(run.parent.name).to eq('general') # Setups to not have numbered names
    expect(run.parent.desc).to eq('General')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    _timestamp, _severity, _progname, message = run.logs.first

    expect(message).to eq('do some setting up')
  end

  it 'should run successfully' do
    run = @runs.find { |x| x.parent.desc == 'should run successfully' }

    expect(run.parent.file).to end_with('specs/general.spec.rb:7')
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

  it 'should run with an error' do
    run = @runs.find { |x| x.parent.desc == 'should run with an error' }

    expect(run.error).to be_kind_of(RuntimeError)
    expect(run.error.message).to eq('Oops!')
    expect(run.failure).to eq(nil)
    expect(run.logs.count).to eq(1)

    _, severity, progname, message = run.logs.first

    expect(progname).to eq('spectre')
    expect(severity).to eq('FATAL')
    expect(message).to start_with('Oops!')
  end

  it 'should run with a failure' do
    run = @runs.find { |x| x.parent.desc == 'should run with a failure' }

    expect(run.error).to eq(nil)

    expect(run.failure).to be_kind_of(Spectre::Expectation::ExpectationFailure)
    expect(run.failure.message).to eq('fail for fun')
    expect(run.failure.desc).to eq(nil)

    expect(run.logs.count).to eq(1)

    _, severity, progname, message = run.logs.first

    expect(progname).to eq('spectre')
    expect(severity).to eq('ERROR')
    expect(message).to eq('fail for fun - in specs/general.spec.rb:33')
  end

  it 'runs: should run with an expectation failure' do
    run = @runs.find { |x| x.parent.desc == 'should run with an expectation failure' }

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

  it 'observes a process' do
    run = @runs.find { |x| x.parent.desc == 'observes a process' }

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)

    expect(run.logs.count).to eq(2)

    expect(run.logs[0][3]).to eq('expected 666 to be 42, but got 666')
    expect(run.logs[1][3]).to eq('continues to run')
  end
end
