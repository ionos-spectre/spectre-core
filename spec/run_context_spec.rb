# RSpec.describe 'Output' do
#   it 'should have a pretty output' do
#     runs = Spectre
#       .setup({
#         'specs' => [],
#         'tags' => [],
#         'formatter' => 'Spectre::ConsoleFormatter',
#         'stdout' => $stdout,
#         # 'debug' => true,
#       })
#       .run
#
#     Spectre.report(runs)
#   end
# end

RSpec.describe Spectre::RunContext do
  before do
    @console_out = StringIO.new
    @log_out = StringIO.new

    Spectre
      .setup({
        'log_file' => @log_out,
        'stdout' => @console_out,
      })

    @subject = Spectre::DefinitionContext.new('Some subject')
    @spec = Spectre::Specification.new(
      @subject,
      'test',
      'a desc',
      [:some_tag],
      [],
      'path/to/file',
      nil
    )
  end

  after do
    @log_out.close
    @console_out.close
  end

  it 'executes successfully' do
    log_message = 'this is a log message'
    bag = {foo: 'bar'}

    run_context = Spectre::RunContext.new(@spec, :spec, bag) do |context|
      context.execute([]) do
        Spectre.info log_message
      end

      expect(Spectre::RunContext.current).to be(context)
    end

    expect(run_context.name).to eq(@spec.name)
    expect(run_context.type).to eq(:spec)

    expect(run_context.evaluations.count).to eq(0)
    expect(run_context.error).to eq(nil)
    expect(run_context.status).to eq(:success)

    expect(run_context.started).not_to eq(nil)
    expect(run_context.finished).not_to eq(nil)
    expect(run_context.duration).not_to eq(nil)

    expect(run_context.bag.foo).to eq('bar')
    expect(run_context.logs.count).to eq(1)

    log = run_context.logs.first

    expect(DateTime.parse(log[0])).not_to eq(nil)
    expect(log[1]).to eq('INFO')
    expect(log[2]).to eq('spectre')
    expect(log[3]).to eq(log_message)

    @log_out.rewind
    log = @log_out.readlines
    expect(log.count).to eq(1)

    log_format = '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}[+\-]\d{2}:\d{2}\]  ' \
                 'INFO -- spectre: \[test\] \[\] this is a log messag'

    expect(log.first).to match(log_format)

    @console_out.rewind
    lines = @console_out.readlines
    expect(lines.count).to eq(1)
    expect(lines.first).to eq("this is a log message#{'.' * 59}#{'[info]'.blue}\n")
  end

  it 'lets define a group' do
    run_context = Spectre::RunContext.new(@spec, :spec) do |context|
      context.execute([]) do
        group 'test group' do
          Spectre.info 'this is a log message'
        end
      end
    end

    expect(run_context.status).to eq(:success)
    expect(run_context.logs.count).to eq(2)
    expect(run_context.logs.first[1]).to eq('DEBUG')
    expect(run_context.logs.first[3]).to eq('group "test group"')
  end

  it 'aborts a run' do
    run_context = Spectre::RunContext.new(@spec, :spec) do |context|
      context.execute([]) do
        Spectre.info 'this is a log message'

        raise Spectre::AbortException

        # rubocop:disable Lint/UnreachableCode
        Spectre.info 'this will never be logged'
        # rubocop:enable Lint/UnreachableCode
      end
    end

    expect(run_context.status).to eq(:success)
    expect(run_context.logs.count).to eq(1)
  end

  it 'skips a run' do
    run_context = Spectre::RunContext.new(@spec, :spec) do |context|
      context.execute([]) do
        Spectre.info 'this is a log message'

        raise Interrupt

        # rubocop:disable Lint/UnreachableCode
        Spectre.info 'this will never be logged'
        # rubocop:enable Lint/UnreachableCode
      end
    end

    expect(run_context.status).to eq(:skipped)
    expect(run_context.logs.count).to eq(2)
    expect(run_context.logs[1][3]).to eq('a desc - canceled by user')
  end

  it 'runs with given data' do
    run_context = Spectre::RunContext.new(@spec, :spec) do |context|
      context.execute({message: 'foo'}) do |data|
        Spectre.info "data is #{data.message}"
      end
    end

    expect(run_context.status).to eq(:success)
    expect(run_context.logs.count).to eq(1)
    expect(run_context.logs.first[3]).to eq('data is foo')
  end

  context 'evaluation' do
    %i[assert expect].each do |method|
      expected_log_count = method == :assert ? 1 : 2

      context method do
        it 'a positive evaluation' do
          run_context = Spectre::RunContext.new(@spec, :spec) do |context|
            context.execute(nil) do
              send(method, OpenStruct.new({to_s: 'something'}))

              Spectre.info 'another log message'
            end
          end

          expect(run_context.logs.count).to eq(expected_log_count)
          expect(run_context.status).to eq(:success)
          expect(run_context.evaluations.count).to eq(1)

          @console_out.rewind
          lines = @console_out.read.lines
          expect(lines.first).to eq("#{method} something#{'.' * 64}#{'[ok]'.green}\n")

          @log_out.rewind
          log = @log_out.readlines
          expect(log.count).to eq(expected_log_count)
          expect(log.first).to end_with("#{method} something - ok\n")
        end

        it 'a failure' do
          run_context = Spectre::RunContext.new(@spec, :spec) do |context|
            context.execute(nil) do
              send(method, OpenStruct.new({
                failure: 'oops',
                to_s: 'something',
                call_location: caller_locations,
              }))

              Spectre.info 'another log line'
            end
          end

          expect(run_context.status).to eq(:failed)
          failures = run_context.evaluations.map(&:failures).flatten
          expect(failures.count).to eq(1)

          failure = failures.first

          expect(failure.message).to eq('oops')
          expected_filepath = __FILE__.sub(Dir.pwd, '.')
          expect(failure.file).to eq(expected_filepath)
          expect(failure.line).not_to eq(nil)
          expect(failure.to_s).to start_with('oops')
          expect(failure.to_s).to match(" - in #{expected_filepath}:\\d+")

          @console_out.rewind
          lines = @console_out.read.lines
          expect(lines.first).to eq("#{method} something#{'.' * 64}#{'[failed]'.red}\n")

          @log_out.rewind
          log = @log_out.readlines
          expect(log.count).to eq(expected_log_count)
          expect(log.first).to end_with("#{method} something - failed\n")
        end

        it 'a block' do
          desc = 'a block to be executed'
          message = 'another log message'

          run_context = Spectre::RunContext.new(@spec, :spec) do |context|
            context.execute(nil) do
              send(method, desc) do
                # do nothing here
                # the evaluation should end with ok status
              end

              Spectre.info message
            end
          end

          log_count = method == :assert ? 1 : 2

          expect(run_context.logs.count).to eq(log_count)
          expect(run_context.status).to eq(:success)
          expect(run_context.evaluations.count).to eq(1)

          @console_out.rewind
          lines = @console_out.read.lines

          expect(lines[0]).to eq("#{method} #{desc}#{'.' * 51}#{'[ok]'.green}\n")
          expect(lines[1]).to eq("#{message}#{'.' * 61}#{'[info]'.blue}\n") unless method == :assert

          @log_out.rewind
          log = @log_out.readlines

          expect(log.count).to eq(log_count)
          expect(log[0]).to end_with("#{method} #{desc} - ok\n")
          expect(log[1]).to end_with("#{message}\n") unless method == :assert
        end

        it 'a block reporting a failure' do
          desc = 'a block to be executed'
          run_context = Spectre::RunContext.new(@spec, :spec) do |context|
            context.execute(nil) do
              send(method, desc) do
                report failure 'oops'
              end

              Spectre.info 'another message'
            end
          end

          expect(run_context.logs.count).to eq(method == :assert ? 1 : 2)
          expect(run_context.status).to eq(:failed)
          expect(run_context.evaluations.first.failures.count).to eq(1)
          expect(run_context.evaluations.first.failures.first.message).to eq('oops')

          @console_out.rewind
          lines = @console_out.read.lines

          expect(lines[0]).to eq("#{method} #{desc}#{'.' * 51}#{'[failed]'.red}\n")
        end
      end
    end
  end
end
