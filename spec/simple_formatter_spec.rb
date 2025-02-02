RSpec.describe Spectre::SimpleFormatter do
  before do
    @console_out = StringIO.new
    @log_out = StringIO.new

    Spectre
      .setup({
        'log_file' => @log_out,
        'stdout' => @console_out,
      })

    subject1 = Spectre::DefinitionContext.new('Some subject')
    subject1.it 'does something', tags: [:some_tag] do
      # do nothing
    end

    subject2 = Spectre::DefinitionContext.new('Another subject')
    subject2.it 'does another thing', tags: [:some_tag, :another_tag] do
      # do nothing
    end

    context = Spectre::DefinitionContext.new('a sub', subject2)
    context.it 'does something in another context', tags: [:a_sub_tag] do
      # do nothing
    end

    @specs = []
    @specs.concat(subject1.all_specs, subject2.all_specs, context.all_specs)
  end

  it 'lists specs' do
    console_out = StringIO.new
    formatter = Spectre::SimpleFormatter.new({'stdout' => console_out})

    formatter.list(@specs)

    console_out.rewind
    lines = console_out.readlines

    expect(lines.count).to eq(3)

    expect(lines[0]).to eq("#{'[some_subject-1]'.blue} Some subject does " \
                           "something #{'#some_tag'.cyan}\n")
    expect(lines[1]).to eq("#{'[another_subject-1]'.magenta} Another subject does another thing " \
                           "#{'#some_tag #another_tag'.cyan}\n")
    expect(lines[2]).to eq("#{'[another_subject-2]'.magenta} Another subject a sub does " \
                           "something in another context #{'#a_sub_tag'.cyan}\n")
  end

  it 'output spec details' do
    console_out = StringIO.new
    formatter = Spectre::SimpleFormatter.new({'stdout' => console_out})

    formatter.details(@specs)

    console_out.rewind
    lines = console_out.readlines

    expect(lines.count).to eq(18)

    expect(lines[0]).to eq("#{'[some_subject-1]'.blue}\n")
    expect(lines[1]).to eq("  subject..: Some subject\n")
    expect(lines[2]).to eq("  desc.....: does something\n")
    expect(lines[3]).to eq("  tags.....: some_tag\n")
    expect(lines[4]).to eq("  file.....: ./spec/simple_formatter_spec.rb:13\n")

    expect(lines[6]).to eq("#{'[another_subject-1]'.magenta}\n")
    expect(lines[7]).to eq("  subject..: Another subject\n")
    expect(lines[8]).to eq("  desc.....: does another thing\n")
    expect(lines[9]).to eq("  tags.....: some_tag, another_tag\n")
    expect(lines[10]).to eq("  file.....: ./spec/simple_formatter_spec.rb:18\n")
  end
end
