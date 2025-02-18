RSpec.describe Spectre::Specification do
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

  it 'defines a subject' do
    subject = Spectre::DefinitionContext.new('Some subject', nil)

    subject.setup do
      info 'message in first setup'
    end

    subject.setup do
      info 'message in second setup'
    end

    subject.teardown do
      info 'message in first teardown'
    end

    subject.teardown do
      info 'message in second teardown'
    end

    subject.before do
      info 'message in first before'
    end

    subject.before do
      info 'message in second before'
    end

    subject.after do
      info 'message in first after'
    end

    subject.after do
      info 'message in second after'
    end

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

    runs = subject.run(@engine, subject.specs)

    expect(runs.count).to eq(4)
    expect(runs[0].status).to eq(:success)
    expect(runs[1].status).to eq(:success)
    expect(runs[2].status).to eq(:success)
    expect(runs[3].status).to eq(:success)

    @console_out.rewind
    lines = @console_out.readlines
    expect(lines.count).to eq(29)

    expect(lines[0]).to eq("#{'Some subject'.blue}\n")

    [1, 3].each do |i|
      expect(lines[i]).to eq("  #{'setup'.magenta}\n")
    end

    [25, 27].each do |i|
      expect(lines[i]).to eq("  #{'teardown'.magenta}\n")
    end
  end

  [
    proc { raise StandardError, 'Oops!' },
    proc { assert('a fact') { report failure 'fail' } },
  ].each do |block|
    it 'does not run when setup fails' do
      subject = Spectre::DefinitionContext.new('Some subject', nil)

      subject.setup(&block)

      subject.it 'does something' do
        # :nocov:
        info 'a message'
        # :nocov:
      end

      subject.teardown do
        info 'some cleanup'
      end

      runs = subject.run(@engine, subject.specs)

      expect(runs.count).to eq(2)
    end
  end

  it 'preserves bags between runs' do
    subject = Spectre::DefinitionContext.new('Some subject', nil)

    subject.setup do
      bag.foo = 42
    end

    subject.it 'does something' do
      bag.foo = 666
      bag.bar = 42
    end

    subject.it 'another thing' do
      info bag.foo
    end

    subject.teardown do
      info bag.foo
    end

    runs = subject.run(@engine, subject.specs)

    expect(runs.all? { |x| x.status == :success }).to eq(true)

    expect(runs[0].bag.foo).to eq(42)
    expect(runs[1].bag.foo).to eq(666)
    expect(runs[2].bag.foo).to eq(42)
    expect(runs[2].bag.bar).to be_nil
    expect(runs[3].bag.foo).to eq(42)
    expect(runs[3].bag.bar).to be_nil
  end

  it 'defines child contexts' do
    subject = Spectre::DefinitionContext.new('Some subject', nil)

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

    expect(subject.children.count).to eq(1)
    expect(subject.children.first.name).to eq('some_subject-first_child_context')
    expect(subject.children.first.root).to be(subject)
    expect(subject.children.first.children.count).to eq(1)
    expect(subject.children.first.children.first.name).to eq('some_subject-first_child_context-another_child')
    expect(subject.children.first.children.first.root).to be(subject)

    runs = subject.run(@engine, subject.all_specs)

    expect(runs.count).to eq(3)
  end
end
