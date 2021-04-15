describe 'spectre/mixin' do
  it 'should run a mixin without parameters', tags: [:mixin] do
    check 'mixin run' do
      run 'some routine'
    end
  end

  it 'should run a mixin with parameters', tags: [:mixin] do
    run 'check some value', with: ['foo', 'foo']
  end
end