Spectre.describe 'Some subject' do
  it 'does something', tags: [:success, :first_tag] do
    Spectre.info 'this is just a log message'
  end

  it 'does something', tags: [:success, :ignore, :second_tag] do
    # :nocov:
    Spectre.info 'this will be ignored'
    # :nocov:
  end

  it 'loads resources', tags: [:success, :second_tag] do
    assert 'the resource to exist' do
      report failure 'file does not exist' unless File.exist? Spectre.resources['dummy.txt']
    end
  end
end
