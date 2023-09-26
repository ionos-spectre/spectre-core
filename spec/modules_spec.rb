require_relative '../lib/spectre'

RSpec.describe 'spectre' do
  it 'loads specified modules' do
    config_file = File.join(File.dirname(__FILE__), './resources/spectre.yml')

    config = Spectre.load(config_file)

    spectre_scope = Spectre.setup(config)

    expected_modules = config['modules']

    expected_modules.all? do |mod|
      expect($LOADED_FEATURES.any? { |f| f.include? mod }).to eq(true)
    end
  end

  it 'does not load excluded modules' do
    config_file = File.join(File.dirname(__FILE__), './resources/spectre.yml')

    config = Spectre.load(config_file)

    config['exclude'] = ['spectre/assertion']

    spectre_scope = Spectre.setup(config)

    config['exclude'].each do |mod|
      expect($LOADED_FEATURES.any? { |f| f.include? mod }).to eq(false)
    end
  end
end