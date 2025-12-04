RSpec.describe Spectre::Specification do
  before do
    @engine = Spectre::Engine
      .new({
        'log_file' => StringIO.new,
        'stdout' => StringIO.new,
      })

    @subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)
  end

  it 'creates a specification with proper attributes' do
    block = proc do
      info 'a message'
    end

    spec = Spectre::Specification.new(
      @subject,
      'test',
      'does something',
      [:some_tag],
      [],
      'path/to/file',
      block
    )

    expect(spec.name).to eq('test')
    expect(spec.full_desc).to eq('Some subject does something')
    expect(spec.tags).to eq([:some_tag])
    expect(spec.root).to be @subject
    expect(spec.block).to eq(block)
  end
end
