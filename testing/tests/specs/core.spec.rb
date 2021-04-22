describe 'spectre/core' do
  context 'fails in before block' do
    before do
      expect 'something' do
        fail_with 'Opps!'
      end
    end

    it 'compares two equal strings and fails', tags: [:core, :before, :fatal] do
      info 'do something'
    end
  end

  context 'fails in after block' do
    after do
      expect 'something' do
        fail_with 'Opps!'
      end
    end

    it 'compares two equal strings and fails', tags: [:core, :after, :fatal] do
      info 'do something'
    end
  end
end