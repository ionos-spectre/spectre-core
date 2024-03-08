RSpec.describe 'Bag' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['bag-*'],
        'stdout' => StringIO.new,
      })
      .run
  end

  it 'uses bag in definition and spec' do
    run = @runs.find { |x| x.parent.desc == 'uses bag in definition and spec' }

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
  end

  it 'does reset bag on every spec run' do
    run = @runs.find { |x| x.parent.desc == 'does reset bag on every spec run' }

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
  end
end
