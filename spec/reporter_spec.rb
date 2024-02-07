require_relative '../lib/spectre'

RSpec.describe 'Reporter' do
  before do
    $stdout = StringIO.new
  end

  after do
    $stdout = STDOUT
  end

  it 'does generate a console report' do
    runs = Spectre
      .setup({
        'specs' => [],
        'tags' => [],
        'formatter' => 'Spectre::ConsoleFormatter',
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
        # 'debug' => true,
      })
      .run

    Spectre.report(runs) 
  end
end
