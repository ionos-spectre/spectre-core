require_relative '../lib/spectre/core'
require_relative '../lib/spectre/runner'

require 'json'

RSpec.describe 'spectre/resources' do
  it 'does read resources' do
    config = {
      'resource_paths' => ['.'],
      'working_dir' => [File.join(File.absolute_path(File.dirname __FILE__), 'resources')],
    }

    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)
    module_context = Spectre::ModuleContext.new(spectre_scope, config)

    spectre_scope.load_modules(['../lib/spectre/resources'], config)

    spectre_context.describe 'Some Subject' do
      it 'does some stuff', tags: [:test, :dummy] do
        log resources['dummy.txt'].content
      end
    end

    run_infos = spectre_scope.run(spectre_scope.specs)

    expect(run_infos.count).to eq(1)

    run_info = run_infos.first

    expect(run_info.error).to eq(nil)
    expect(run_info.failure).to eq(nil)
    expect(run_info.log.first).to eq('Hello Spectre!')
  end
end
