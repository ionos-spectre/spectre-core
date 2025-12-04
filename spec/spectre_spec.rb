RSpec.describe Spectre do
  before do
    @console_out = StringIO.new
    @work_dir = File.join(File.dirname(__FILE__), 'example')
    @log_file = File.join(@work_dir, 'logs', 'spectre.log')
    @global_config_file = File.join(@work_dir, 'global_spectre.yml')
    @config_file = File.join(@work_dir, 'spectre.yml')
  end

  after do
    FileUtils.rm_rf(File.dirname(@log_file))
  end

  it 'sets up a project and runs it' do
    engine = Spectre::Engine
      .new({
        'global_config_file' => @global_config_file,
        'log_file' => @log_file,
        'stdout' => @console_out,
        'work_dir' => @work_dir,
        'tags' => ['success+!ignore'],
        'selected_env' => 'staging',
        'modules' => [
          # Make spectre to load a relative module
          './modules/some_module.rb',
          # and let it load an installed one
          'stringio',
        ],
      })

    # Test if the local module was loaded
    expect(SOME_MODULE_VAR).to eq('foo')
    # Check if the global config was loaded
    expect(engine.env.some_global_var).to eq('what ever')
    # Check if the env file was loaded
    expect(engine.env.foo).to eq('buff')
    # Check if the partial env file was loaded
    expect(engine.env.some_secret).to eq('bar')
    # Check if spectre config was loaded
    expect(engine.env.some_config_var).to eq(42)

    specs = engine.list

    expect(specs.count).to eq(2)

    runs = engine.run

    expect(runs.all? { |x| x.status == :success })

    engine.report(runs)

    expect(File.exist?(@log_file)).to eq(true)

    @console_out.rewind
    output = @console_out.read

    expect(output).to match('\d+ succeeded 0 failures 0 errors 0 skipped')
  end

  it 'lists all specs' do
    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => [],
        'tags' => [],
      })

    specs = engine.list

    expect(specs.count).to eq(3)
  end

  it 'filters by specs' do
    filter = ['example_subject-1', 'example_subject-3']

    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => filter,
        'tags' => [],
      })

    specs = engine.list

    expect(specs.count).to eq(2)
    expect(specs.map(&:name)).to eq(filter)
  end

  it 'filters by tags' do
    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => [],
        'tags' => ['second_tag'],
      })

    specs = engine.list

    expect(specs.count).to eq(2)
    expect(specs.map(&:name)).to eq(['example_subject-2', 'example_subject-3'])
  end

  it 'filters by excluded tags' do
    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => [],
        'tags' => ['second_tag+!ignore'],
      })

    specs = engine.list

    expect(specs.count).to eq(1)
    expect(specs.map(&:name)).to eq(['example_subject-3'])
  end

  it 'filters by multiple tags' do
    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => [],
        'tags' => ['second_tag+!ignore', 'success'],
      })

    specs = engine.list

    expect(specs.count).to eq(3)
  end

  it 'filters by tags and specs' do
    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => ['example_subject-3'],
        'tags' => ['first_tag'],
      })

    specs = engine.list

    expect(specs.count).to eq(2)
    expect(specs.map(&:name)).to eq(['example_subject-1', 'example_subject-3'])
  end

  it 'only runs before blocks in its own definition block' do
    engine = Spectre::Engine.new({
      'stdout' => @console_out,
      'spec_patterns' => [],
    })

    engine.describe 'Some Subject' do
      before do
        info 'first before'
      end
    end

    engine.describe 'Some Subject' do
      before do
        info 'second before'
      end

      it 'runs a spec' do
        info 'some actions'
      end
    end

    runs = engine.run

    expect(runs.count).to eq(1)
    expect(@console_out.string).not_to include('first before')
  end

  it 'enumerates specs with correct numbers, even if defined in separate DefinitionContext' do
    engine = Spectre::Engine.new({
      'stdout' => @console_out,
      'spec_patterns' => [],
    })

    engine.describe 'Some Subject' do
      it 'does something' do
        info 'some actions'
      end
    end

    engine.describe 'Some Subject' do
      it 'does another thing' do
        info 'some actions'
      end
    end

    names = engine.list.map(&:name)

    expect(names).to include('some_subject-1')
    expect(names).to include('some_subject-2')
  end

  it 'sorts specs with natural ordering' do
    engine = Spectre::Engine.new({
      'stdout' => @console_out,
      'spec_patterns' => [],
      'formatter' => 'Spectre::SimpleFormatter',
    })

    # Create enough specs to test natural sorting (need to go beyond 9)
    engine.describe 'Test Subject' do
      (1..12).each do |i|
        it "does something #{i}" do
          info 'some actions'
        end
      end
    end

    specs = engine.list
    names = specs.map(&:name)

    # Natural sort should order: 1, 2, 3, ..., 9, 10, 11, 12
    # NOT lexicographic: 1, 10, 11, 12, 2, 3, ..., 9
    expected_order = (1..12).map { |i| "test_subject-#{i}" }
    expect(names).to eq(expected_order)

    # Verify the formatter outputs them in the correct order
    engine.formatter.list(specs)
    @console_out.rewind
    output = @console_out.read

    # Check that spec-10 appears after spec-9 and before spec-11 in the output
    spec_9_pos = output.index('[test_subject-9]')
    spec_10_pos = output.index('[test_subject-10]')
    spec_11_pos = output.index('[test_subject-11]')

    expect(spec_9_pos).to be < spec_10_pos
    expect(spec_10_pos).to be < spec_11_pos
  end
end
