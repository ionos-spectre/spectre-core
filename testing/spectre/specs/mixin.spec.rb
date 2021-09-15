describe 'spectre/mixin' do
  it 'should run a mixin without parameters', tags: [:mixin] do
    observe 'mixin run' do
      run 'some routine'
    end

    expect 'the mixin run to be successful' do
      success?.should_be true
    end
  end

  it 'should run a mixin with list parameters', tags: [:mixin] do
    run 'check some value', with: ['foo', 'foo']
  end

  it 'should run a mixin with hash parameters', tags: [:mixin] do
    run 'something with params', with: {bar: 'foo'}
  end
end