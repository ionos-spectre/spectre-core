RSpec.describe Spectre::SimpleReporter do
  it 'reports a successful run' do
    Spectre
      .setup({
        'log_file' => StringIO.new,
        'stdout' => StringIO.new,
      })

    subject = Spectre::DefinitionContext.new('Some subject')

    subject.it 'does something' do
      Spectre.info 'a message'
    end

    runs = subject.run(subject.specs)

    report_output = StringIO.new

    Spectre::SimpleReporter
      .new({'stdout' => report_output})
      .report(runs)

    report_output.rewind
    lines = report_output.readlines

    expect(lines[0]).to eq("#{'1 succeeded 0 failures 0 errors 0 skipped'.green}\n")
  end

  it 'reports a failed run' do
    subject = Spectre::DefinitionContext.new('Some subject')

    subject.it 'does something' do
      Spectre.info 'a message'
    end

    subject.it 'does something stupid' do
      assert 'some truth' do
        report failure 'a bad thing happened'
      end
    end

    subject.it 'does mupltile stupid things' do
      expect 'nothing to happen' do
        # do nothing here
      end

      expect 'some truth' do
        report failure 'a bad thing happened'
      end

      expect 'some truth' do
        report failure 'a bad thing happened'
        report failure 'and another bad thing'
      end

      assert 'another truth' do
        report failure 'a bad thing happened'
        report failure 'and another bad one'
      end
    end

    subject.it 'does another bad thing' do
      raise StandardError, 'Oops!'
    end

    Spectre
      .setup({
        'log_file' => StringIO.new,
        'stdout' => StringIO.new,
      })

    runs = subject.run(subject.specs)

    report_output = StringIO.new

    Spectre::SimpleReporter
      .new({'stdout' => report_output})
      .report(runs)

    report_output.rewind
    lines = report_output.readlines

    puts "\n#{lines.join}"

    expect(lines[0]).to eq("#{'1 succeeded 2 failures 1 errors 0 skipped'.red}\n")
    expect(lines[2]).to match('1\) Some subject does something stupid \(.*\) \[some_subject-2\]')
    expect(lines[3]).to eq("     assert some truth, but a bad thing happened\n")
    expect(lines[14]).to match('3\) Some subject does another bad thing \(.*\) \[some_subject-4\]')
    expect(lines[15]).to eq("     but an unexpected error occurred during run\n")
    expect(lines[16]).to match('       file\.+: ./spec/simple_reporter_spec\.rb:\d+')
    expect(lines[17]).to eq("       type.....: StandardError\n")
    expect(lines[18]).to eq("       message..: Oops!\n")
  end
end
