require_relative '../lib/spectre'

RSpec.describe 'Environment' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['environment-*'],
        'formatter' => 'Spectre::NoopFormatter',
      })
      .run
  end

  it 'should access a variable from the environment' do
    run = @runs[0]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
  end

  it 'should access a variable from a partial environment' do
    run = @runs[1]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
  end

  it 'should use env variable in spec definition' do
    run = @runs[2]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
  end
end
