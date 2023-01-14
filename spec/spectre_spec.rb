require_relative '../lib/spectre'

RSpec.describe 'spectre' do
  it 'loads and setups config and environment from files' do
    config_file = File.join File.dirname(__FILE__), './resources/spectre.yml'

    config = Spectre.load(config_file, 'default')

    expect(config['foo']).to eq('bar')

    spectre_scope = config = Spectre.setup(config)

    Spectre.run(spectre_scope, spectre_scope.specs)

    expect(run_infos.count).to eq(1)
  end
end