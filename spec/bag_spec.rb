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

  [
    'uses bag in definition and spec',
    'does reset bag on every spec run',
  ].each do |desc|
    it desc do
      run = @runs.find { |x| x.parent.desc == desc }
  
      expect(run.error).to eq(nil)
      expect(run.failure).to eq(nil)
    end
  end
end
