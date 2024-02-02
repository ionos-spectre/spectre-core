%i{debug info warn}.each do |method|
  define_method(method) do |*args, &block|
    Spectre.logger.send(method, *args, &block)
  end
end

Spectre.describe 'General' do
  setup do
    info 'do some setting up'
  end

  it 'should run successfully' do
    info 'some info'
    info "this is a\nmultiline message"
  end
end

Spectre.describe 'General' do
  it 'another general run defined in different block' do
    info 'some info'
  end
end

