describe 'spectre/environment' do
  it 'should provide environment variables', tags: [:env] do
    expect 'foo to be in env' do
      env.foo.should_be 'bar'
    end
  end
end