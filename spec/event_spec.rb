require 'spectre'

RSpec.describe 'spectre/event' do
  before do
    Spectre.purge
  end

  it 'does run specs' do
    Spectre.describe 'Some Subject' do
      setup do
        log 'do some setup stuff once'
      end

      teardown do
        log 'do some teardown stuff once'
      end

      before do
        log 'do some stuff before each run'

        bag.foo = 'bar'
      end

      after do
        log 'do some stuff after each run'
      end

      it 'does some stuff', tags: [:test, :dummy] do
        log 'do some stuff'
        info 'log some info'
        debug 'log some debug info'
      end
    end

    run_infos = Spectre::Runner.new.run(Spectre.specs)

    expect(run_infos.count).to eq(3)

    run_info = run_infos[1]
  end
end
