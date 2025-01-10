RSpec.describe 'Mixin' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['mixin-*'],
        'stdout' => StringIO.new,
      })
      .run
  end

  it 'runs some mixin' do
    run = @runs[0]

    expect(run.parent.desc).to eq('executes a mixin')
    expect(run.logs.count).to eq(2)

    expect(run.logs[0][3]).to eq('execute mixin "run some mixin"')
    expect(run.logs[1][3]).to eq('some info from within a mixin')
  end

  it 'runs some mixin with list parameters' do
    run = @runs[1]

    expect(run.logs.count).to eq(3)
  end

  it 'runs some mixin with hash parameters' do
    run = @runs[2]

    expect(run.logs.count).to eq(2)
  end

  it 'runs some mixin with bag access' do
    run = @runs.find { |x| x.parent.desc == 'uses a bag value within a mixin' }

    expect(run.logs.count).to eq(2)
  end
end
