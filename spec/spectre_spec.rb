RSpec.describe Spectre do
  it 'sets up a project and runs it' do
    console_out = StringIO.new

    work_dir = File.join(File.dirname(__FILE__), 'example')
    log_file = File.join(work_dir, 'logs', 'spectre.log')

    Spectre
      .setup({
        'global_config_file' => File.join(work_dir, 'global_spectre.yml'),
        'log_file' => log_file,
        'stdout' => console_out,
        'work_dir' => work_dir,
        'tags' => ['success+!ignore'],
        'modules' => [
          # Make spectre to load a relative module
          './modules/some_module.rb',
          # and let is load a installed one
          'stringio',
        ],
      })

    # Test if the local module was loaded
    expect(SOME_MODULE_VAR).to eq('foo')
    # Check if the global config was loaded
    expect(Spectre.env.some_global_var).to eq('what ever')
    # Check if the env file was loaded
    expect(Spectre.env.foo).to eq('bar')
    # Check if the partial env file was loaded
    expect(Spectre.env.some_secret).to eq('bar')
    # Check if spectre config was loaded
    expect(Spectre.env.some_config_var).to eq(42)

    specs = Spectre.list

    expect(specs.count).to eq(2)

    runs = Spectre.run

    expect(File.exist?(log_file)).to eq(true)
    FileUtils.rm_rf(File.dirname(log_file))

    expect(runs.all? { |x| x.status == :success })

    Spectre.report(runs)

    console_out.rewind
    output = console_out.read

    expect(output).to match('\d+ succeeded 0 failures 0 errors 0 skipped')
  end
end
