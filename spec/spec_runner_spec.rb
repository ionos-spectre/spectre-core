RSpec.describe 'Spec Execution' do
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

  describe 'DefinitionContext#run' do
    it 'runs a context with setup, teardown, before, after blocks' do
      subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

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

      specs_set = Set.new(subject.specs)
      runs = subject.run(specs_set)

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
      it 'does not run specs when setup fails' do
        subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

        subject.setup(&block)

        subject.it 'does something' do
          # :nocov:
          info 'a message'
          # :nocov:
        end

        subject.teardown do
          info 'some cleanup'
        end

        specs_set = Set.new(subject.specs)
        runs = subject.run(specs_set)

        expect(runs.count).to eq(2)
      end
    end

    it 'preserves bags between runs' do
      subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

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

      specs_set = Set.new(subject.specs)
      runs = subject.run(specs_set)

      expect(runs.all? { |x| x.status == :success }).to eq(true)

      expect(runs[0].bag.foo).to eq(42)
      expect(runs[1].bag.foo).to eq(666)
      expect(runs[2].bag.foo).to eq(42)
      expect(runs[2].bag.bar).to be_nil
      expect(runs[3].bag.foo).to eq(42)
      expect(runs[3].bag.bar).to be_nil
    end

    it 'runs child contexts and nested contexts' do
      subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

      subject.it 'does a main thing' do
        info 'a message'
      end

      subject.context 'first child context' do
        setup do
          # Nothing to do here
        end

        teardown do
          # Nothing to do here
        end

        it 'does things' do
          info 'a message'
        end

        context 'another child' do
          setup do
            # Nothing to do here
          end

          teardown do
            # Nothing to do here
          end

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

      specs = @engine.contexts.flat_map(&:specs)
      specs_set = Set.new(specs)

      runs = subject.run(specs_set)

      expect(runs.count).to eq(7)

      expect(runs[0].name).to eq('some_subject-1')
      expect(runs[0].context.name).to eq('some_subject')

      expect(runs[1].name).to eq('some_subject-first_child_context-setup')
      expect(runs[1].context.name).to eq('some_subject-first_child_context')

      expect(runs[2].name).to eq('some_subject-2')
      expect(runs[2].context.name).to eq('some_subject-first_child_context')

      expect(runs[3].name).to eq('some_subject-first_child_context-teardown')
      expect(runs[3].context.name).to eq('some_subject-first_child_context')

      expect(runs[4].name).to eq('some_subject-first_child_context-another_child-setup')
      expect(runs[4].context.name).to eq('some_subject-first_child_context-another_child')

      expect(runs[5].name).to eq('some_subject-3')
      expect(runs[5].context.name).to eq('some_subject-first_child_context-another_child')

      expect(runs[6].name).to eq('some_subject-first_child_context-another_child-teardown')
      expect(runs[6].context.name).to eq('some_subject-first_child_context-another_child')
    end

    it 'runs specs in deeply nested contexts when filtering by tags' do
      subject = Spectre::DefinitionContext.new('Level 1', nil, @engine)

      subject.it 'spec at level 1', tags: [:top] do
        info 'at level 1'
      end

      subject.context 'Level 2' do
        it 'spec at level 2', tags: [:middle] do
          info 'at level 2'
        end

        context 'Level 3' do
          it 'spec at level 3', tags: [:deep] do
            info 'at level 3'
          end

          context 'Level 4' do
            it 'spec at level 4', tags: [:deepest] do
              info 'at level 4'
            end
          end
        end
      end

      # Filter to only run the deepest spec
      filtered_specs = @engine.list({ 'specs' => [], 'tags' => ['deepest'] })
      expect(filtered_specs.count).to eq(1)
      expect(filtered_specs[0].name).to eq('level_1-4')

      specs_set = Set.new(filtered_specs)
      runs = subject.run(specs_set)

      # Should have exactly 1 run (the deepest spec)
      expect(runs.count).to eq(1)
      expect(runs[0].name).to eq('level_1-4')
      expect(runs[0].status).to eq(:success)

      # Verify the spec actually ran
      @console_out.rewind
      output = @console_out.read
      expect(output).to include('at level 4')
    end

    it 'only outputs contexts that have matching specs when filtering' do
      subject = Spectre::DefinitionContext.new('Root', nil, @engine)

      subject.it 'first spec', tags: [:foo] do
        info 'in first spec'
      end

      subject.context 'Child A' do
        it 'second spec', tags: [:bar] do
          info 'in second spec'
        end
      end

      subject.context 'Child B' do
        it 'third spec', tags: [:baz] do
          info 'in third spec'
        end

        context 'Grandchild B1' do
          it 'fourth spec', tags: [:qux] do
            info 'in fourth spec'
          end
        end
      end

      # Filter to only run specs with :bar tag
      filtered_specs = @engine.list({ 'specs' => [], 'tags' => ['bar'] })
      expect(filtered_specs.count).to eq(1)

      specs_set = Set.new(filtered_specs)
      runs = subject.run(specs_set)

      # Should only have 1 run
      expect(runs.count).to eq(1)
      expect(runs[0].name).to eq('root-2')

      # Check console output - should show root and matching child, but not non-matching children
      @console_out.rewind
      output = @console_out.read

      expect(output).to include('Root')
      expect(output).to include('Child A')
      expect(output).not_to include('Child B')
      expect(output).not_to include('Grandchild B1')
    end
  end

  describe 'Specification#run' do
    before do
      @subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)
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

  describe 'Engine#run with reporting' do
    it 'reports a successful run' do
      subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

      subject.it 'does something' do
        info 'a message'
      end

      specs_set = Set.new(subject.specs)
      runs = subject.run(specs_set)

      report_output = StringIO.new

      Spectre::SimpleReporter
        .new({'stdout' => report_output})
        .report(runs)

      report_output.rewind
      lines = report_output.readlines

      expect(lines[0]).to eq("#{'1 succeeded 0 failures 0 errors 0 skipped'.green}\n")
    end

    it 'reports a failed run' do
      subject = Spectre::DefinitionContext.new('Some subject', nil, @engine)

      subject.it 'does something' do
        info 'a message'
      end

      subject.it 'does something stupid' do
        assert 'some truth' do
          report 'a bad thing happened'
        end
      end

      subject.it 'does mupltile stupid things' do
        expect 'nothing to happen' do
          # do nothing here
        end

        expect 'some truth' do
          report 'a bad thing happened'
        end

        expect 'some truth' do
          report 'a bad thing happened'
          report 'and another bad thing'
        end

        assert 'another truth' do
          report 'a bad thing happened'
          report 'and another bad one'
        end
      end

      subject.it 'does another bad thing' do
        raise StandardError, 'Oops!'
      end

      specs_set = Set.new(subject.specs)
      runs = subject.run(specs_set)

      report_output = StringIO.new

      Spectre::SimpleReporter
        .new({'stdout' => report_output})
        .report(runs)

      report_output.rewind
      lines = report_output.readlines

      expect(lines[0]).to eq("#{'1 succeeded 2 failures 1 errors 0 skipped'.red}\n")
      expect(lines[2]).to match('1\) Some subject does something stupid \(.*\) \[some_subject-2\]')
      expect(lines[3]).to eq("     assert some truth, but a bad thing happened\n")
      expect(lines[14]).to match('3\) Some subject does another bad thing \(.*\) \[some_subject-4\]')
      expect(lines[15]).to eq("     but an unexpected error occurred during run\n")
      expect(lines[16]).to match('       file\.+: ./spec/spec_runner_spec\.rb:\d+')
      expect(lines[17]).to eq("       type.....: StandardError\n")
      expect(lines[18]).to eq("       message..: Oops!\n")
    end
  end
end
