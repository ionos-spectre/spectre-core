require_relative '../lib/spectre'
require_relative '../lib/spectre/config'

RSpec.describe 'spectre/bootstrap' do
  before do
    @config_file = './spectre.yml'
    @env_file = './default.env.yml'

    File.write(@config_file, YAML.dump({
      'env_patterns' => ['*.env.yml'],
      'bla' => 'blubb',
      'foo' => 'bar',
    }))

    File.write(@env_file, YAML.dump({
      'bla' => 'blubber',
    }))
  end

  after do
    File.delete(@config_file)
    File.delete(@env_file)
  end

  it 'does load everything' do
    config = Spectre::Config.load()

    expect(config['bla']).to eq('blubb')

    config = Spectre::Environment
      .load(config)
      .select('default')

    expect(config).not_to eq(nil)
    expect(config['bla']).to eq('blubber')

    expect(Spectre::Environment.envs.count).to eq(Spectre::Environment.envs.count)
    expect(Spectre::Environment.envs.key? 'default').to be(true)
  end
end
