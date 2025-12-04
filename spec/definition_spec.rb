RSpec.describe Spectre::DefinitionContext do
  before do
    @console_out = StringIO.new
    @log_out = StringIO.new

    @engine = Spectre::Engine
      .new({
        'log_file' => @log_out,
        'stdout' => @console_out,
      })
  end

  after do
    @log_out.close
    @console_out.close
  end

  it 'defines a subject with specs and child contexts' do
    subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

    subject.it 'does something' do
      info 'a message'
    end

    subject.it 'does another thing' do
      info 'another message'
    end

    expect(subject.name).to eq('some_subject')
    expect(subject.full_desc).to eq('Some subject')
    expect(subject.root).to be(subject)

    expect(subject.specs.count).to eq(2)
    expect(subject.specs[0].name).to eq('some_subject-1')
    expect(subject.specs[1].name).to eq('some_subject-2')
  end

  it 'creates nested child contexts with proper hierarchy' do
    subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

    subject.it 'does a main thing' do
      info 'a message'
    end

    subject.context 'first child context' do
      it 'does things' do
        info 'a message'
      end

      context 'another child' do
        it 'does another thing' do
          info 'another message'
        end
      end
    end

    children = @engine.contexts.select { |x| x.parent == subject }

    expect(children.count).to eq(1)
    first_child = children.first
    expect(first_child.name).to eq('some_subject-first_child_context')
    expect(first_child.root).to be(subject)

    children = @engine.contexts.select { |x| x.parent == first_child }

    expect(children.count).to eq(1)
    expect(children.first.name).to eq('some_subject-first_child_context-another_child')
    expect(children.first.root).to be(subject)
  end
end
