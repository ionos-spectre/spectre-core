describe 'spectre/logger' do
  it 'logs messages', tags: [:log, :core] do
    info 'this is a info message'
    log 'this is a log message'
    debug 'this is a debug message'

    separate 'a separator'

    info 'another info after separation'

    group 'here comes a group messages' do
      info 'here we go'
      debug "let's do some debugging"
      log 'and off we go'
    end
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

      separate 'a separator'

      info 'another info after separation'

      group 'here comes a group messages' do
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

    it 'logs messages in another context', tags: [:log, :setup, :core] do
      info 'this is a info message'
      log 'this is a log message'
      debug 'this is a debug message'

      separate 'a separator'

      info 'another info after separation'

      group 'here comes a group messages' do
        info 'here we go'
        debug "let's do some debugging"
        log 'and off we go'
      end
    end
  end
end