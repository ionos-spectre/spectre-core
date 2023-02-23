require_relative '../lib/spectre/core'
require_relative '../lib/spectre/runner'
require_relative '../lib/spectre/assertion'

require 'json'

RSpec.describe 'spectre/core' do
  it 'does run specs in new scope directly' do
    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)

    spectre_context.describe 'Some Subject' do
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

        property 'foo', 'bar'

        sleep 0.1

        expect 'some stuff' do
          42.should_be 42
        end

        expect 'some stuff to break' do
          fail_with 'Oops!'
        end
      end
    end

    run_infos = Spectre::Runner.new(spectre_scope).run(spectre_scope.specs)

    expect(run_infos.count).to eq(3)

    expect(run_infos[0].log.count).to eq(1)
    expect(run_infos[2].log.count).to eq(1)

    run_info = run_infos[1]

    expect(run_info.error).to eq(nil)
    expect(run_info.expectations.count).to eq(2)
    expect(run_info.log.count).to eq(5)
    expect(run_info.events.count).to eq(13)
    expect(run_info.failure).not_to eq(nil)
    expect(run_info.properties['foo']).to eq('bar')
    expect(run_info.skipped).to eq(false)
  end

  it 'does run specs in new scope from spec file' do
    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)

    spectre_scope.load_specs(['resources/spec_test.rb'], File.absolute_path(File.dirname __FILE__))

    run_infos = Spectre::Runner.new(spectre_scope).run(spectre_scope.specs)

    expect(run_infos.count).to eq(3)

    expect(run_infos[0].log.count).to eq(1)
    expect(run_infos[2].log.count).to eq(1)

    run_info = run_infos[1]

    expect(run_info.error).to eq(nil)
    expect(run_info.expectations.count).to eq(2)
    expect(run_info.log.count).to eq(5)
    expect(run_info.events.count).to eq(13)
    expect(run_info.failure).not_to eq(nil)
    expect(run_info.properties['foo']).to eq('bar')
    expect(run_info.skipped).to eq(false)
  end

  it 'does run specs with extensions' do
    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)

    class TestExtension
      def initialize logger
        @logger = logger
      end

      def greet name
        @logger.info("Hello #{name}!")
      end
    end

    mod_name = 'spectre/test'

    Spectre::SpectreScope.define mod_name do |config, logger, _scope|
      register :greet do |_run_info|
        TestExtension.new(logger)
      end
    end

    spectre_context.describe 'Some Subject' do
      it 'does some stuff', tags: [:test, :dummy] do
        log 'do some stuff'
        greet 'Spectre'
      end
    end

    spectre_scope.configure({})

    run_infos = Spectre::Runner.new(spectre_scope).run(spectre_scope.specs)

    expect(run_infos.count).to eq(1)

    run_info = run_infos.first

    expect(run_info.error).to eq(nil)
    expect(run_info.failure).to eq(nil)
    expect(run_info.log.count).to eq(2)
    expect(run_info.log[1][3]).to eq(mod_name)
    expect(run_info.events.count).to eq(3)
  end

  it 'does run specs with extensions from module file' do
    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)

    require_relative 'resources/test_mod'

    spectre_context.describe 'Some Subject' do
      it 'does some stuff', tags: [:test, :dummy] do
        greet 'Spectre'
      end
    end

    spectre_scope.configure({})

    run_infos = Spectre::Runner.new(spectre_scope).run(spectre_scope.specs)

    expect(run_infos.count).to eq(1)

    run_info = run_infos.first

    expect(run_info.error).to eq(nil)
    expect(run_info.failure).to eq(nil)
    expect(run_info.log.count).to eq(1)
  end

  it 'does run specs with environment' do
    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)

    spectre_scope.configure({foo: 'bar'})

    spectre_context.describe 'Some Subject' do
      it 'does some stuff', tags: [:test, :dummy] do
        log "env foo is #{env.foo}"
      end
    end

    run_infos = Spectre::Runner.new(spectre_scope).run(spectre_scope.specs)

    expect(run_infos.first.error).to eq(nil)
    expect(run_infos.first.log.first[1]).to eq('env foo is bar')
  end

  it 'filters specs' do
    spectre_scope = Spectre::SpectreScope.new
    spectre_context = Spectre::SpectreContext.new(spectre_scope)

    spectre_scope.configure({foo: 'bar'})

    spectre_context.describe 'Some Subject' do
      it 'foo', tags: [:test, :dummy, :foo] do
      end

      it 'bar', tags: [:test, :dummy, :bar] do
      end

      it 'bla', tags: [:test, :bla] do
      end
    end

    specs = spectre_scope.specs(['some_subject-1'])
    expect(specs.count).to eq(1)
    expect(specs.first.name).to eq('some_subject-1')

    specs = spectre_scope.specs(['some_subject-*'])
    expect(specs.count).to eq(3)

    specs = spectre_scope.specs([], ['foo'])
    expect(specs.count).to eq(1)
    expect(specs.first.desc).to eq('foo')

    specs = spectre_scope.specs([], ['!foo'])
    expect(specs.count).to eq(2)
    expect(specs[0].desc).to eq('bar')
    expect(specs[1].desc).to eq('bla')

    specs = spectre_scope.specs([], ['foo', 'bar'])
    expect(specs.count).to eq(2)
    expect(specs[0].desc).to eq('foo')
    expect(specs[1].desc).to eq('bar')

    specs = spectre_scope.specs([], ['test+dummy'])
    expect(specs.count).to eq(2)
    expect(specs[0].desc).to eq('foo')
    expect(specs[1].desc).to eq('bar')

    specs = spectre_scope.specs([], ['test+!dummy'])
    expect(specs.count).to eq(1)
    expect(specs.first.desc).to eq('bla')
  end
end
