RSpec.describe Spectre::Specification do
  before do
    @console_out = StringIO.new
    @log_out = StringIO.new

    @engine = Spectre::Engine
      .new({
        'log_file' => @log_out,
        'stdout' => @console_out,
      })

    @subject = Spectre::DefinitionContext.new('Some subject', nil)
  end

  after do
    @log_out.close
    @console_out.close
  end

  it 'runs before and after blocks with the same bag' do
    block = proc do
      info "message from the main block #{bag.buff}"
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

    expect(spec.full_desc).to eq('Some subject does something')
    expect(spec.root).to be @subject

    befores = [
      proc do
        info 'message in first before block'
        bag.buff = 42
      end,
      proc { info 'message in second before block' },
    ]

    afters = [
      proc { info 'message in first after block' },
      proc { info 'message in second after block' },
    ]

    bag = { foo: 'bar' }

    run_context = spec.run(@engine, befores, afters, bag)

    expect(run_context.status).to eq(:success)
    expect(run_context.logs.count).to eq(5)

    @console_out.rewind
    lines = @console_out.readlines
    expect(lines.count).to eq(10)

    expect(lines[0]).to eq("#{'does something'.cyan}\n")
    expect(lines[1]).to eq("  #{'before'.magenta}\n")
    expect(lines[2]).to eq("    message in first before block#{'.' * 47}#{'[info]'.blue}\n")
    expect(lines[3]).to eq("  #{'before'.magenta}\n")
    expect(lines[4]).to eq("    message in second before block#{'.' * 46}#{'[info]'.blue}\n")
    expect(lines[5]).to eq("  message from the main block 42#{'.' * 48}#{'[info]'.blue}\n")
    expect(lines[6]).to eq("  #{'after'.magenta}\n")
    expect(lines[7]).to eq("    message in first after block#{'.' * 48}#{'[info]'.blue}\n")
    expect(lines[8]).to eq("  #{'after'.magenta}\n")
    expect(lines[9]).to eq("    message in second after block#{'.' * 47}#{'[info]'.blue}\n")
  end

  it 'runs entire after block on fail' do
    block = proc do
      info 'message from the main block'
      assert 'the run'.to Spectre::Assertion.be 'successful'
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

    expect(spec.full_desc).to eq('Some subject does something')
    expect(spec.root).to be @subject

    afters = [
      proc do
        info 'message in first after block'
        assert 'truth'.to Spectre::Assertion.be 'truth'
        info 'this message should also be logged'
      end,
    ]

    run_context = spec.run(@engine, [], afters, {})

    expect(run_context.status).to eq(:failed)

    expect(run_context.logs.any? { |x| x[4] == 'this message should also be logged' }).to be_truthy
  end

  it 'does not run main block if before fails but always runs after blocks' do
    block = proc do
      # :nocov:
      info 'message from main block'
      # :nocov:
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

    befores = [
      proc do
        info 'message in before block'
        raise StandardError, 'Oops!'
      end,
    ]

    afters = [
      proc { info 'message in after block' },
    ]

    run_context = spec.run(@engine, befores, afters, {})

    expect(run_context.status).to eq(:error)
    expect(run_context.logs.count).to eq(3)

    @console_out.rewind
    lines = @console_out.readlines
    expect(lines.count).to eq(6)

    expect(lines.find { |x| x.include? 'message from main block' }).to be_nil
    expect(lines.find { |x| x.include? 'message in after block' }).not_to be_nil
  end
end
