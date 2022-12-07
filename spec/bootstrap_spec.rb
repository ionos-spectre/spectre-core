require 'spectre'
require 'spectre/bootstrap'

RSpec.describe 'spectre/bootstrap' do
  it 'does load everything' do
    Spectre::Bootstrap.load()
    Spectre::Bootstrap.load_envs()

    config = Spectre::Bootstrap.get_env()

    expect(config).not_to eq(nil)

    # Spectre::Bootstrap.load_modules(config)
    Spectre::Bootstrap.load_mixins(config)
    Spectre::Bootstrap.load_specs(config)
  end
end
