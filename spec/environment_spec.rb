RSpec.describe 'Environment' do
  before do
    @runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['environment-*'],
        'tags' => [],
        'stdout' => StringIO.new,
      })
      .run
  end

  [
    'should access a variable from the environment',
    'should access a variable from a partial environment',
    'should use env variable in spec definition',
  ].each do |desc|
    it desc do
      run = @runs.find { |x| x.parent.desc == desc }
  
      expect(run.error).to eq(nil)
      expect(run.failure).to eq(nil)
    end
  end
end
