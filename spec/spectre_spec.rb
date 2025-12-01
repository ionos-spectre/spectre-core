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
    filter = ['some_subject-1', 'some_subject-2']

    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => filter,
        'tags' => [],
      })

    specs = engine.list

    expect(specs.count).to eq(2)
    expect((filter - specs.map(&:name)).count).to eq(0)
  end

  it 'filters by tags' do
    expected_specs = ['some_subject-2', 'some_subject-3']

    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => [],
        'tags' => ['second_tag'],
      })

    specs = engine.list

    expect(specs.count).to eq(2)
    expect((expected_specs - specs.map(&:name)).count).to eq(0)
  end

  it 'filters by excluded tags' do
    expected_specs = ['some_subject-3']

    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => [],
        'tags' => ['second_tag+!ignore'],
      })

    specs = engine.list

    expect(specs.count).to eq(1)
    expect((expected_specs - specs.map(&:name)).count).to eq(0)
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
    expected_specs = ['some_subject-1', 'some_subject-3']

    engine = Spectre::Engine
      .new({
        'config_file' => @config_file,
        'specs' => ['some_subject-3'],
        'tags' => ['first_tag'],
      })

    specs = engine.list

    expect(specs.count).to eq(2)
    expect((expected_specs - specs.map(&:name)).count).to eq(0)
  end

  it 'creates separate contexts using same name' do
    engine = Spectre::Engine.new({
        'config_file' => @config_file,
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

      it 'run a spec' do
        info 'some actions'
      end
    end

    runs = engine.run

    puts runs[2].logs.inspect

  end
end
