require_relative 'spectre_definitions'

RSpec.describe 'Context' do
  before do
    @runs = Spectre
      .setup({
        'specs' => ['context-*'],
        'formatter' => 'Spectre::NoopFormatter',
      })
      .run
  end

  it 'should run within a child context' do
    run = @runs[0]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)
    expect(run.parent.parent.desc).to eq('within a new context')

    timestamp, _name, _level, message, _status, _desc = run.logs.first

    expect(message).to eq('some info from wihtin a context')
  end
end

