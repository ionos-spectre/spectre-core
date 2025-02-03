describe 'Firehouse' do
  # This block will be executed +once+ at the beginning of this context
  setup do
    # You can add log messages with the following functions
    info 'get the proton back ready'
    # debug 'check the ghost trap for failures'
    # log 'inspection protocol'

    # Use the bag to store some values, which can be used later in every spec
    # Note that you *cannot share a bag* across multible specs.
    bag.inventory = ['proton pack', 'ghost trap']

    # Setup the context in which all the specs within are executed
  end

  # This block will be executed +once+ at the end of this context
  teardown do
    info 'place entities into the containment unit'

    # Do some cleanup (delete temporary resouces, shutdown test system,...) 
    # after all specs have been executed.
    # Multiple blocks can be defined.
    # These blocks are always executed, even errors occured previously
  end

  # This block will be executed *before* each specs runs (+it+ block)
  # Multiple +before+ blocks can be defined
  before do
    info 'activate proton packs'
  end

  # This block will be executed *after* each specs runs (+it+ block)
  # Multiple +after+ blocks can be defined
  after do
    info 'deactivate proton packs'
    info 'seal ghost trap'
  end

  it 'accepts emergency calls', tags: [:emergency, :call] do
    info 'pickup the phone'

    answer = do_phone_call('216 245-2368')

    # "Expecting" something will not abort the test run, even if a failure was reported
    expect 'a classic conversation' do
      report failure 'not the legendary message' unless answer.message == 'Ghostbusters. Whaddaya want?'
      report failure 'wrong caller' unless answer.caller == 'Janine Melnitz'
    end

    # However "asserting" something *will* abort the test run *after* all
    # conditions within the +assert+ block have been checked
    assert "ain't afraid of no ghosts" do
      report failure 'message not correct' unless respone.json.message == 'Hello World!'
      report failure 'incorrect number' unless respone.json.number == 42
    end

    info "won't continue if someone is a coward"
  end

  context 'at midnight' do
    setup do
      info 'get Ecto-1 ready'

      bag.ecto_goggles = true
    end

    teardown do
      info 'do the usual stuff'
    end

    it 'captures some ghosts', tags: [:emergency, :ghosts] do
      info 'shoot the rays'

      raise StandardError, 'rays have been crossed'
    end
  end
end
