describe 'spectre' do
  it 'logs messages', tags: [:log, :core] do
    info 'this is a info message'
    log 'this is a log message'
    debug 'this is a debug message'
  end

  context 'a context' do
    it 'logs messages in a context', tags: [:log, :core] do
      info 'this is a info message'
      log 'this is a log message'
      debug 'this is a debug message'
    end
  end

  context 'another context' do
    it 'logs messages in another context', tags: [:log, :core] do
      info 'this is a info message'
      log 'this is a log message'
      debug 'this is a debug message'
    end
  end

  context 'another context' do
    setup do
      log 'do some setup stuff'
    end

    teardown do
      log 'do some teardown stuff'
    end

    before do
      log 'do some stuff before the spec run'
    end

    after do
      log 'do some stuff after the spec run'
    end

    it 'logs messages in another context', tags: [:log, :setup, :core] do
      info 'this is a info message'
      log 'this is a log message'
      debug 'this is a debug message'
    end
  end
end