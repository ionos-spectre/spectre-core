RSpec.describe 'Context' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['context-*'],
        'stdout' => StringIO.new,
      })
      .run
  end

  it 'should run within a child context' do
    expect(@runs[0].type).to eq(:setup)
    expect(@runs[0].logs[0][3]).to eq('do some setting up')

    expect(@runs[1].type).to eq(:spec)
    expect(@runs[1].logs.count).to eq(3)
    expect(@runs[1].parent.desc).to eq('should run within a main context')
    expect(@runs[1].parent.parent.desc).to eq('Context')
    expect(@runs[1].logs[0][3]).to eq('some info from before in main context')
    expect(@runs[1].logs[1][3]).to eq('some info')
    expect(@runs[1].logs[2][3]).to eq('some info from after in main context')

    expect(@runs[2].type).to eq(:teardown)
    expect(@runs[2].logs[0][3]).to eq('do some tearing down')

    expect(@runs[3].type).to eq(:setup)
    expect(@runs[3].logs[0][3]).to eq('do some setting up in child context')

    expect(@runs[4].logs.count).to eq(3)
    expect(@runs[4].parent.desc).to eq('should run within a child context')
    expect(@runs[4].parent.parent.desc).to eq('within a child context')
    expect(@runs[4].logs[0][3]).to eq('some info from before in child context')
    expect(@runs[4].logs[1][3]).to eq('some info from wihtin a context')
    expect(@runs[4].logs[2][3]).to eq('some info from after in child context')

    expect(@runs[5].logs[0][3]).to eq('do some tearing down in child context')
  end
end
