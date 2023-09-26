require_relative '../lib/spectre'
require_relative '../lib/spectre/assertion'

RSpec.describe 'spectre' do
  it 'loads and setups config and environment from files' do
    config_file = File.join(File.dirname(__FILE__), './resources/spectre.yml')

    config = Spectre.load(config_file)

    expect(config['foo']).to eq('bar')
    expect(config['some_secret']).to eq('supersecret')

    spectre_scope = Spectre.setup(config)

    run_infos = Spectre.run(spectre_scope, spectre_scope.specs)

    expect(run_infos.count).to eq(5)
    expect(run_infos[0].spec.name).to eq('some_subject-setup-1')

    expect(run_infos[1].spec.name).to eq('some_subject-1')
    expect(run_infos[1].success?).to eq(false)
    expect(run_infos[1].error?).to eq(false)
    expect(run_infos[1].failed?).to eq(true)

    expect(run_infos[2].spec.name).to eq('some_subject-teardown-1')
    expect(run_infos[3].spec.name).to eq('some_subject-setup-1')
    expect(run_infos[4].spec.name).to eq('some_subject-2')
    expect(run_infos[4].spec.context.__desc).to eq('some other context')
    expect(run_infos[4].success?).to eq(true)
  end
end