RSpec.describe 'Filter' do
  it 'list only specific specs' do
    specs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['general-1', 'general-2'],
        'tags' => [],
        'stdout' => StringIO.new,
      })
      .list

    expect(specs.count).to eq(2)
  end

  it 'runs only specific specs' do
    specs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['general-1', 'general-2'],
        'tags' => [],
        'stdout' => StringIO.new,
      })
      .run

    expect(specs.count).to eq(3)
  end

  it 'runs specs of a specific subject' do
    runs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['general-*'],
        'tags' => [],
        'stdout' => StringIO.new,
      })
      .run

    expect(runs.count).to eq(12)
    expect(runs.all? { |x| x.parent.root.desc == 'General' }).to eq(true)
  end

  it 'runs with a specific tag' do
    specs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['tag-*'],
        'tags' => ['tagged'],
        'stdout' => StringIO.new,
      })
      .list

    expect(specs.count).to eq(3)
    expect(specs[0].desc).to eq('should run with the tag')
    expect(specs[1].desc).to eq('should also run with tags')
    expect(specs[2].desc).to eq('should not run with this tag')
  end

  it 'runs with multiple tags' do
    specs = Spectre
      .setup({
        'specs' => ['tag-*'],
        'tags' => ['tagged+another_tag'],
        'stdout' => StringIO.new,
      })
      .list

    expect(specs.count).to eq(1)
    expect(specs[0].desc).to eq('should run with the tag')
  end

  it 'runs with different tags' do
    specs = Spectre
      .setup({
        'specs' => ['tag-*'],
        'tags' => ['tagged', 'another_tag'],
        'stdout' => StringIO.new,
      })
      .list

    expect(specs.count).to eq(3)
    expect(specs[0].desc).to eq('should run with the tag')
    expect(specs[1].desc).to eq('should also run with tags')
    expect(specs[2].desc).to eq('should not run with this tag')
  end

  it 'runs without a specific tag' do
    specs = Spectre
      .setup({
        'specs' => ['tag-*'],
        'tags' => ['tagged+!special_tag'],
        'stdout' => StringIO.new,
      })
      .list

    expect(specs.count).to eq(2)
    expect(specs[0].desc).to eq('should run with the tag')
    expect(specs[1].desc).to eq('should also run with tags')
  end
end
