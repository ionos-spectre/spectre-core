RSpec.describe 'Reporter' do
  it 'does generate a console report' do
    runs = Spectre
      .setup({
        'specs' => [],
        'tags' => [],
        'formatter' => 'Spectre::ConsoleFormatter',
        'stdout' => StringIO.new,
        # 'debug' => true,
      })
      .run

    Spectre.report(runs)
  end

  it 'does generate a json report' do
    runs = Spectre
      .setup({
        'specs' => [],
        'tags' => [],
        'formatter' => 'Spectre::JsonFormatter',
        'stdout' => StringIO.new,
        # 'debug' => true,
      })
      .run

    Spectre.report(runs)
  end
end
