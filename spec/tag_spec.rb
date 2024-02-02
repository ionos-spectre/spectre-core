RSpec.describe 'Tag' do
  it 'runs with a specific tag' do
    specs = Spectre
      .setup({
        'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
        'specs' => ['tag-*'],
        'formatter' => 'Spectre::NoopFormatter',
        'tags' => ['tagged'],
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
        'formatter' => 'Spectre::NoopFormatter',
        'tags' => ['tagged+another_tag'],
      })
      .list

    expect(specs.count).to eq(1)
    expect(specs[0].desc).to eq('should run with the tag')
  end

  it 'runs with different tags' do
    specs = Spectre
      .setup({
        'specs' => ['tag-*'],
        'formatter' => 'Spectre::NoopFormatter',
        'tags' => ['tagged', 'another_tag'],
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
        'formatter' => 'Spectre::NoopFormatter',
        'tags' => ['tagged+!special_tag'],
      })
      .list

    expect(specs.count).to eq(2)
    expect(specs[0].desc).to eq('should run with the tag')
    expect(specs[1].desc).to eq('should also run with tags')
  end
end
