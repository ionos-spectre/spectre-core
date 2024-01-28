require_relative '../lib/spectre'

RSpec.describe 'Mixin' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['mixin-*'],
        'formatter' => 'Spectre::NoopFormatter',
      })
      .run
  end

  it 'runs some mixin' do
    run = @runs[0]

    expect(run.failure).to be_nil
    expect(run.error).to be_nil
    expect(run.parent.desc).to eq('executes a mixin')
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs.first

    expect(name).to eq('spectre')
    expect(level).to eq(:info)
    expect(message).to eq('some info from within a mixin')
  end

  it 'runs some mixin with list parameters' do
    run = @runs[1]
    
    expect(run.failure).to be_nil
    expect(run.error).to be_nil
    expect(run.logs.count).to eq(2)
  end

  it 'runs some mixin with hash parameters' do
    run = @runs[2]
    
    expect(run.failure).to be_nil
    expect(run.error).to be_nil
    expect(run.logs.count).to eq(1)
  end
end
