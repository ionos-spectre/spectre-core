require 'spectre'

RSpec.describe 'spectre/core' do
  before do
    Spectre.purge
  end

  it 'does run specs' do
    Spectre.describe 'Some Subject' do
      it 'does some stuff', tags: [:test, :dummy] do
        log 'do some stuff'

        property 'foo', 'bar'

        sleep 0.1

        Spectre::Assertion.expect 'some stuff' do
          42.should_be 42
        end

        Spectre::Assertion.expect 'some stuff to break' do
          fail_with 'Oops!'
        end
      end
    end

    run_infos = Spectre::Runner.new.run(Spectre.specs)

    expect(run_infos.count).to eq(1)

    run_info = run_infos.first

    expect(run_info.expectations.count).to eq(2)
    expect(run_info.log.count).to eq(1)
    expect(run_info.error).to eq(nil)
    expect(run_info.failure).not_to eq(nil)
    expect(run_info.properties['foo']).to eq('bar')
    expect(run_info.skipped).to eq(false)
  end
end
