describe 'spectre/environment' do
  it 'should provide environment variables', tags: [:env] do
    expect 'foo to be in env' do
      env.foo.should_be 'bar'
    end
  end

  it 'should be globally available', tags: [:env], with: [env.foo] do |data|
    expect 'the passed parameter should be same as environment' do
      data.should_be env.foo
    end
  end
end
