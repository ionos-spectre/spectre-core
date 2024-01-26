require_relative 'spectre_definitions'

# Spectre
#   .setup({
#     'specs' => [],
#     'tags' => [],
#     'formatter' => 'Spectre::ConsoleFormatter',
#   })
#   .run

RSpec.describe 'General' do
  before do
    @runs = Spectre
      .setup({
        'specs' => ['general-*'],
        'formatter' => 'Spectre::NoopFormatter',
      })
      .run
  end

  it 'should run' do
    expect(@runs.count).to eq(2)
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
    expect(run.logs.count).to eq(2)
    expect(run.parent.desc).to eq('should run successfully')

    timestamp, name, level, message, status, desc = run.logs.first

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:info)
    expect(message).to eq('some info')
    expect(status).to eq(nil)
    expect(desc).to eq(nil)
  end
end
