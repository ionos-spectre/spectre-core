Spectre.describe 'Tag' do
  it 'should run with the tag', tags: [:tagged, :another_tag] do
    info 'do something tagged'
  end

  it 'should also run with tags', tags: [:tagged] do
    info 'do something tagged'
  end

  it 'should not run with this tag', tags: [:tagged, :special_tag] do
    info 'do something tagged'
  end

  it 'has no tags' do
    info 'do something without any tags'
  end
end
