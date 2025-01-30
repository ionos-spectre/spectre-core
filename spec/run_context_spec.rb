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
    # @runs = Spectre
    #   .setup({
    #     'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
    #     'specs' => ['general-*'],
    #     'stdout' => StringIO.new,
    #   })
    #   .run

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

  it 'executes successfully' do
    log_message = 'this is a log message'
    bag = {foo: 'bar'}

    run_context = Spectre::RunContext.new(@spec, :spec, bag) do |context|
      context.execute([]) do
        info log_message
      end

      expect(Spectre::RunContext.current).to be(context)
    end

    expect(run_context.name).to eq(@spec.name)
    expect(run_context.type).to eq(:spec)

    expect(run_context.failures.count).to eq(0)
    expect(run_context.error).to eq(nil)
    expect(run_context.skipped?).to eq(false)
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
  end

  it 'lets define a group' do
    run_context = Spectre::RunContext.new(@spec, :spec) do |context|
      context.execute([]) do
        group 'test group' do
          info 'this is a log message'
        end
      end
    end

    expect(run_context.logs.count).to eq(2)
    expect(run_context.logs.first[1]).to eq('DEBUG')
    expect(run_context.logs.first[3]).to eq('group "test group"')
  end

  it 'aborts a run' do
    run_context = Spectre::RunContext.new(@spec, :spec) do |context|
      context.execute([]) do
        info 'this is a log message'

        raise Spectre::AbortException

        # rubocop:disable Lint/UnreachableCode
        info 'this will never be logged'
        # rubocop:enable Lint/UnreachableCode
      end
    end

    expect(run_context.failures.count).to eq(0)
    expect(run_context.error).to eq(nil)
    expect(run_context.skipped?).to eq(false)
    expect(run_context.logs.count).to eq(1)
  end

  it 'skips a run' do
    run_context = Spectre::RunContext.new(@spec, :spec) do |context|
      context.execute([]) do
        info 'this is a log message'

        raise Interrupt

        # rubocop:disable Lint/UnreachableCode
        info 'this will never be logged'
        # rubocop:enable Lint/UnreachableCode
      end
    end

    expect(run_context.skipped?).to eq(true)
    expect(run_context.failures.count).to eq(0)
    expect(run_context.error).to eq(nil)
    expect(run_context.logs.count).to eq(2)
    expect(run_context.logs[1][3]).to eq('a desc - canceled by user')
  end
end
