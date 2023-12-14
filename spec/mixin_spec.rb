require_relative '../lib/spectre/core'
require_relative '../lib/spectre/runner'

require 'json'

RSpec.describe 'spectre/mixin' do
  it 'does run specs with extensions' do
    config = {
      'mixin_patterns' => ['test_mixin.rb'],
      'working_dir' => [File.join(File.absolute_path(File.dirname __FILE__), 'resources')],
    }

    require_relative '../lib/spectre/mixin'

    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)
    _module_context = Spectre::ModuleContext.new(spectre_scope)

    spectre_scope.configure(config)

    spectre_context.describe 'Some Subject' do
      it 'does some stuff', tags: [:test, :dummy] do
        log 'do some stuff'

        also 'do some additional testing'
      end
    end

    run_infos = Spectre::Runner.new(spectre_scope).run(spectre_scope.specs)

    expect(run_infos.count).to eq(1)

    run_info = run_infos.first

    expect(run_info.error).to eq(nil)
    expect(run_info.failure).to eq(nil)
  end
end
