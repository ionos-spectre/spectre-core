Spectre::Engine.current.describe 'Some subject' do
  it 'does something', tags: [:success, :first_tag] do
    info 'this is just a log message'
  end

  it 'does something', tags: [:success, :ignore, :second_tag] do
    # :nocov:
    info 'this will be ignored'
    # :nocov:
  end

  it 'loads resources', tags: [:success, :second_tag] do
    assert 'the resource to exist' do
      # report failure 'file does not exist' unless File.exist? engine.resources['dummy.txt']
      report failure 'file does not exist' unless File.exist? resources['dummy.txt']
    end
  end
end
