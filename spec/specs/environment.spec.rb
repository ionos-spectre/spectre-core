Spectre.describe 'Environment' do
  it 'should access a variable from the environment' do
    env.foo.should be 'bar'
  end

  it 'should access a variable from a partial environment' do
    env.some_secret.should be 'some_secret_value'
  end

  it 'should use env variable in spec definition', with: [env.foo] do |data|
    data.should be 'bar'
  end

  env.some_data.each do |data|
    it 'should use env variable in spec definition' do
      data.should be 'foo'.or 'bar'
    end
  end
end
