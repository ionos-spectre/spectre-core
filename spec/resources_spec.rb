require_relative '../lib/spectre/core'
require_relative '../lib/spectre/runner'
require_relative '../lib/spectre/resources'

require 'json'

require_relative '../lib/spectre/helpers'

RSpec.describe 'spectre/resources' do
  it 'does read resources' do
    working_dir = File.join(File.absolute_path(File.dirname __FILE__), 'resources')

    config = {
      'resource_paths' => [working_dir],
      'working_dir' => [working_dir],
    }

    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)
    module_context = Spectre::ModuleContext.new(spectre_scope)

    spectre_context.describe 'Some Subject' do
      it 'does some stuff', tags: [:test, :dummy] do
        log resources['dummy.txt'].content
      end
    end

    spectre_scope.configure(config)

    run_infos = Spectre::Runner.new(spectre_scope).run(spectre_scope.specs)

    expect(run_infos.count).to eq(1)

    run_info = run_infos.first

    expect(run_info.error).to eq(nil)
    expect(run_info.failure).to eq(nil)
    expect(run_info.log.first[1]).to eq('Hello Spectre!')
  end
end
