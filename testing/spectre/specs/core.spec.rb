describe 'spectre/core' do
  context 'fails in before block' do
    before do
      expect 'nothing' do
        fail_with 'Oops!'
      end
    end

    it 'compares two equal strings and fails', tags: [:core, :before, :fatal] do
      info 'do something'
    end
  end

  context 'fails in after block' do
    after do
      expect 'nothing' do
        fail_with 'Oops!'
      end
    end

    it 'compares two equal strings and fails', tags: [:core, :after, :fatal] do
      info 'do something'
    end
  end

  context 'unexpected failures' do
    it 'compares two equal strings and fails', tags: [:core, :before, :fatal] do
      expect 'nothing' do
        fail 'Oops!'
      end
    end
  end

  it 'should fail with not defined variable', tags: [:core, :undefined, :fatal] do
    webspace
  end
end