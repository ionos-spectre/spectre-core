describe 'spectre/logging' do
  it 'logs messages', tags: [:log, :logging] do
    info 'this is a info message'
    log 'this is a log message'
    debug 'this is a debug message'

    info 'another info after separation'

    group 'grouping some message' do
      info 'here we go'
      debug "let's do some debugging"
      log 'and off we go'
    end
  end

  context 'a context' do
    it 'logs messages in a context', tags: [:log, :logging] do
      info 'this is a info message'
      log 'this is a log message'
      debug 'this is a debug message'
    end
  end

  context 'another context' do
    it 'logs messages in another context', tags: [:log, :logging] do
      info 'this is a info message'
      log 'this is a log message'
      debug 'this is a debug message'
    end
  end

  context 'another context' do
    setup do
      log 'do some setup stuff'

      info 'another info after separation'

      group 'grouping some message' do
        info 'here we go'
        debug "let's do some debugging"
        log 'and off we go'
      end
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

    it 'logs messages in another context', tags: [:log, :setup, :logging] do
      info 'this is a info message'
      log 'this is a log message'
      debug 'this is a debug message'

      info 'another info after separation'

      group 'here comes a group messages' do
        info 'here we go'
        debug "let's do some debugging"
        log 'and off we go'
      end
    end
  end
end
