describe 'Ghostbuster' do
  # This block will be executed +once+ at the beginning of this context
  setup do
    # You can add log messages with the following functions
    info 'get the proton back ready'
    debug 'check the ghost trap for failures'
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

  it 'accepts emergency calls', tags: [:emergency, :call, :failed, :expect, :assert] do
    info 'pickup the phone'

    answer = do_phone_call('216 245-2368')

    # "Expecting" something will not abort the test run, even if a failure was reported
    expect 'a classic conversation' do
      report 'no legendary answer was given' unless answer.message == 'Ghostbusters. Whaddaya want?'
      report 'wrong caller' unless answer.caller == 'Janine Melnitz'
    end

    # However "asserting" something *will* abort the test run *after* all
    # conditions within the +assert+ block have been checked
    assert "ain't afraid of no ghosts" do
      report 'trap was not ready'
      report 'fears itself'
    end

    info "won't continue if someone is a coward"
  end

  it 'hunts at the Sedgewick Hotel', tags: [:ghosts, :success, :expect, :assert] do
    entity_color = 'green'
    entity_desc = 'A real nasty one!'
    storage_facility = ['Ghoul', 'Library ghost', 'Ivo Shandor']

    expect entity_color.to be 'green'
    assert entity_desc.to match 'nasty'
    expect entity_desc.not to be 'Class V entity'
    assert storage_facility.to contain 'Ghoul'
  end

  context 'at midnight' do
    setup do
      info 'get Ecto-1 ready'

      bag.ecto_goggles = true
    end

    teardown do
      info 'do the usual stuff'
    end

    it 'captures some ghosts', tags: [:emergency, :ghosts, :error, :group, :mixin] do
      # Run the mixin with the given description
      # Mixins help to run reusable logic with given parameters
      # Do use mixins for *test logic*
      # If you want reusable code which wraps additional technical
      # functions (like database connection, ...) consider implementing
      # a custom spectre module
      also "consult Tobin's Spirit Guide" do
        with entity: 'Zuul'
        with occurance: 'refrigerator'
      end

      group 'together' do
        info 'Grab your stick!'
        debug "HOLDIN'!"
        info "Heat 'em up!"
        debug "SMOKIN'!"
        info "Make 'em hard!"
        debug 'READY!'
        info 'THROW IT!'
      end

      info 'try to capture entity'

      group 'together again' do
        info 'shoot the streams'
        info "don't panic"
        info 'keep it steady'
      end

      # An unexpected error will abort the current test run with status +error+
      raise StandardError, 'streams have been crossed and that is bad'
    end
  end
end

##
# You can describe multiple subject in one file.
# However it is recommended to split each subject in separate files.
# Also consider using multiple files for one subject
#
describe 'Firehouse' do
  it 'is the home of the Ladder 8 company', tags: [:trivia] do
    info "it's name is Hook & Ladder Company 8 Firehouse"
    info 'located at 14 North Moore Street'
  end

  it 'has a functioning containment unit', tags: [:fails, :observe, :expect, :assert] do
    # Use observe to capture any error wihtin the block
    observe 'containment unit' do
      raise StandardError, 'a blackout occured'
    end

    expect success?.to be true

    # The status of the observation can be retrieved wiht +success?+
    unless success?
      info 'but backup battery in place'
      debug 'set recovery time to 3 seconds after blackout'
    end

    observe 'containment unit again' do
      debug 'is possessed by Killerwatt'
      info 'use generator from Ecto-1'
      info 'tell Peter to buy a bicycle'
      debug 'rig up and keep the unit going'
    end

    assert 'the unit to work how' do
      report 'cracks began to appear in the retaining wall' unless success?
    end
  end
end
