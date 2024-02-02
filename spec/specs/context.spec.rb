Spectre.describe 'Context' do
  setup do
    info 'do some setting up'
  end

  teardown do
    info 'do some tearing down'
  end

  before do
    info 'some info from before in main context'
  end

  after do
    info 'some info from after in main context'
  end

  it 'should run within a main context' do
    info 'some info'
  end

  context 'within a child context' do
    setup do
      info 'do some setting up in child context'
    end

    teardown do
      info 'do some tearing down in child context'
    end

    before do
      info 'some info from before in child context'
    end

    after do
      info 'some info from after in child context'
    end

    it 'should run within a child context' do
      info 'some info from wihtin a context'
    end
  end
end
