require_relative '../lib/spectre/expectation'

RSpec.describe Spectre::Expectation do
  before do
    @console_out = StringIO.new
    @log_out = StringIO.new

    @subject = Spectre::DefinitionContext.new('Some subject', nil)
    @spec = Spectre::Specification.new(
      @subject,
      'test',
      'a desc',
      [:some_tag],
      [],
      'path/to/file',
      nil
    )

    @engine = Spectre::Engine
      .new({
        'log_file' => @log_out,
        'stdout' => @console_out,
      })
  end

  it 'executes should be' do
    run_context = Spectre::RunContext.new(@engine, @spec, :spec) do |context|
      context.execute(nil) do
        expect 'a specific value' do
          value = 666
          value.should_be 42
        end
      end
    end

    expect(run_context.status).to eq(:failed)
    expect(run_context.evaluations.count).to eq(1)
    expect(run_context.evaluations.first.failures.count).to eq(1)

    failure = run_context.evaluations.first.failures.first

    expect(failure.file).to eq('./spec/expectation_spec.rb')
  end

  it 'executes should not be' do
    run_context = Spectre::RunContext.new(@engine, @spec, :spec) do |context|
      context.execute(nil) do
        expect 'a specific value' do
          value = 666
          value.should_not_be 666
        end
      end
    end

    expect(run_context.status).to eq(:failed)
    expect(run_context.evaluations.first.failures.count).to eq(1)
  end

  it 'executes should be empty' do
    run_context = Spectre::RunContext.new(@engine, @spec, :spec) do |context|
      context.execute(nil) do
        expect 'a specific value' do
          value = [1, 2]
          value.should_be_empty
        end
      end
    end

    expect(run_context.status).to eq(:failed)
    expect(run_context.evaluations.first.failures.count).to eq(1)
  end

  it 'executes should not be empty' do
    run_context = Spectre::RunContext.new(@engine, @spec, :spec) do |context|
      context.execute(nil) do
        expect 'a specific value' do
          value = []
          value.should_not_be_empty
        end
      end
    end

    expect(run_context.status).to eq(:failed)
    expect(run_context.evaluations.first.failures.count).to eq(1)
  end

  it 'executes should not exist' do
    run_context = Spectre::RunContext.new(@engine, @spec, :spec) do |context|
      context.execute(nil) do
        expect 'a specific value' do
          value = 666
          value.should_not_exist
        end
      end
    end

    expect(run_context.status).to eq(:failed)
    expect(run_context.evaluations.first.failures.count).to eq(1)
  end

  it 'executes should contain' do
    run_context = Spectre::RunContext.new(@engine, @spec, :spec) do |context|
      context.execute(nil) do
        expect 'a specific value' do
          value = [1, 2]
          value.should_contain 42
        end
      end
    end

    expect(run_context.status).to eq(:failed)
    expect(run_context.evaluations.first.failures.count).to eq(1)
  end

  it 'executes should not contain' do
    run_context = Spectre::RunContext.new(@engine, @spec, :spec) do |context|
      context.execute(nil) do
        expect 'a specific value' do
          value = [1, 2, 666]
          value.should_not_contain 666
        end
      end
    end

    expect(run_context.status).to eq(:failed)
    expect(run_context.evaluations.first.failures.count).to eq(1)
  end
end
