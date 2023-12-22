# frozen_string_literal: true

require 'rspec'

require_relative '../lib/spectre'

Spectre::CONFIG['log_file'] = nil

Spectre.describe 'Test' do
  setup do
    Spectre.logger.info 'do some setting up'
  end

  it 'should run successfully' do
    Spectre.logger.info 'some info'
  end

  it 'should expect some truthy block' do
    the_truth = 42

    expect 'to succeed' do
      the_truth.should Spectre::Expectation.be 42
    end
  end

  it 'should expect some truth' do
    the_truth = 42

    the_truth.should Spectre::Expectation.be 42
  end
end

Spectre.setup({})

RUNS = Spectre.run

RSpec.describe 'Spectre' do
  it 'should run' do
    expect(RUNS.count).to eq(4)
  end

  it 'should run some setup' do
    run = RUNS[0]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, _name, _level, message, _status, _desc = run.logs.first

    expect(timestamp).to be_kind_of(DateTime)
    expect(message).to eq('do some setting up')
  end

  it 'should run a spec successfully' do
    run = RUNS[1]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs.first

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:info)
    expect(message).to eq('some info')
    expect(status).to eq(nil)
    expect(desc).to eq(nil)
  end

  it 'should run a spec with an expectation block' do
    run = RUNS[2]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:debug)
    expect(message).to eq('expect to succeed')
    expect(status).to eq(:ok)
    expect(desc).to eq(nil)
  end

  it 'should run a spec with a direct expectation' do
    run = RUNS[3]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:debug)
    expect(message).to eq('expect the_truth to be 42')
    expect(status).to eq(:ok)
    expect(desc).to eq(nil)
  end
end
