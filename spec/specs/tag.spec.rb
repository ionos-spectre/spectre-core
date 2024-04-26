Spectre.describe 'Tag' do
  it 'should run with the tag', tags: [:success, :tagged, :another_tag] do
    info 'do something tagged'
  end

  it 'should also run with tags', tags: [:success, :tagged] do
    info 'do something tagged'
  end

  it 'should not run with this tag', tags: [:success, :tagged, :special_tag] do
    info 'do something tagged'
  end

  it 'has no tags' do
    info 'do something without any tags'
  end
end
