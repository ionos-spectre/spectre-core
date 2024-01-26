# frozen_string_literal: true

require 'rspec'

require_relative '../lib/spectre'

Spectre::CONFIG['log_file'] = nil

Spectre.describe 'Logging' do
  setup do
    Spectre.logger.info 'do some setting up'
  end

  it 'should run successfully' do
    Spectre.logger.info 'some info'
    Spectre.logger.info "this is a\nmultiline message"
  end
end

Spectre.describe 'Expectation' do
  it 'evaluates within an expect block' do
    the_truth = 42

    expect 'to succeed' do
      the_truth.should Spectre::Expectation.be 42
    end
  end

  it 'evaluates "should_not be"' do
    the_truth = 42

    the_truth.should_not Spectre::Expectation.be 666
  end

  it 'evaluates "should be"' do
    the_truth = 42

    the_truth.should Spectre::Expectation.be 42
  end

  it 'evaluates "should contain and" with a list' do
    the_truth_list = [42, 666, 86]
    the_truth_list.should Spectre::Expectation.contain 42.and 86
  end

  it 'evaluates "should be or" with a single value' do
    the_truth = 42
    the_truth.should Spectre::Expectation.be 42.or 86
  end

  it 'evaluates "should contain or" with a list' do
    the_truth_list = [42, 666]
    the_truth_list.should Spectre::Expectation.contain 42.or 86
  end

  it 'evaluate "should match"' do
    the_truth = 'the truth is 42'
    the_truth.should Spectre::Expectation.match /42/
  end
end

Spectre.describe 'Context' do
  context 'within a new context' do
    it 'should run within a child context' do
      Spectre.logger.info 'some info from wihtin a context'
    end
  end
end

Spectre.describe 'Tag' do
  it 'should run with the tag', tags: [:tagged, :another_tag] do
    Spectre.logger.info 'do something tagged'
  end

  it 'should also run with tags', tags: [:tagged] do
    Spectre.logger.info 'do something tagged'
  end

  it 'should not run with this tag', tags: [:tagged, :special_tag] do
    Spectre.logger.info 'do something tagged'
  end
end


# Run spectre

all_runs = Spectre
  .setup({})
  .run

runs_with_tags = Spectre
  .setup({
    'formatter'=> 'Spectre::NoopFormatter',
    'tags' => ['tagged']
  })
  .run

runs_with_multiple_tags = Spectre
  .setup({
    'formatter'=> 'Spectre::NoopFormatter',
    'tags' => ['tagged+another_tag']
  })
  .run

runs_with_different_tags = Spectre
  .setup({
    'formatter'=> 'Spectre::NoopFormatter',
    'tags' => ['tagged', 'another_tag']
  })
  .run

runs_without_tag = Spectre
  .setup({
    'formatter'=> 'Spectre::NoopFormatter',
    'tags' => ['tagged+!special_tag']
  })
  .run


# Describe RSpec tests

RSpec.describe 'General' do
  it 'should run' do
    expect(all_runs.count).to eq(13)
  end
end

RSpec.describe 'Logging' do
  it 'runs: setup' do
    run = all_runs[0]

    expect(run.parent.desc).to eq('Logging')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, _name, _level, message, _status, _desc = run.logs.first

    expect(timestamp).to be_kind_of(DateTime)
    expect(message).to eq('do some setting up')
  end

  it 'runs: should run successfully' do
    run = all_runs[1]

    expect(run.parent.parent.desc).to eq('Logging')
    expect(run.parent.desc).to eq('should run successfully')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(2)
    expect(run.parent.desc).to eq('should run successfully')

    timestamp, name, level, message, status, desc = run.logs.first

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:info)
    expect(message).to eq('some info')
    expect(status).to eq(nil)
    expect(desc).to eq(nil)
  end
end

RSpec.describe 'Expectation' do
  it 'runs: evaluates within an expect block' do
    run = all_runs[2]

    expect(run.parent.parent.desc).to eq('Expectation')
    expect(run.error).to eq(nil)
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

  it 'runs: evaluates "should_not be"' do
    run = all_runs[3]

    expect(run.parent.parent.desc).to eq('Expectation')
    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(timestamp).to be_kind_of(DateTime)
    expect(name).to eq('spectre')
    expect(level).to eq(:debug)
    expect(message).to eq('expect the_truth not to be 666')
    expect(status).to eq(:ok)
    expect(desc).to eq(nil)
  end

  it 'runs: evaluates "should be"' do
    run = all_runs[4]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(message).to eq('expect the_truth to be 42')
    expect(status).to eq(:ok)
  end

  it 'evaluates "should contain and" with a list' do
    run = all_runs[5]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(message).to eq('expect the_truth_list to contain 42 and 86')
    expect(status).to eq(:ok)
  end

  it 'evaluates "should be or" with a single value' do
    run = all_runs[6]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(message).to eq('expect the_truth to be 42 or 86')
    expect(status).to eq(:ok)
  end

  it 'evaluates "should contain or" with a list' do
    run = all_runs[7]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(message).to eq('expect the_truth_list to contain 42 or 86')
    expect(status).to eq(:ok)
  end

  it 'evaluate "should match"' do
    run = all_runs[8]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)

    timestamp, name, level, message, status, desc = run.logs[0]

    expect(message).to eq('expect the_truth to match /42/')
    expect(status).to eq(:ok)
  end
end

RSpec.describe 'Context' do
  it 'should run within a child context' do
    run = all_runs[9]

    expect(run.error).to eq(nil)
    expect(run.failure).to eq(nil)
    expect(run.skipped).to eq(false)
    expect(run.logs.count).to eq(1)
    expect(run.parent.parent.desc).to eq('within a new context')

    timestamp, _name, _level, message, _status, _desc = run.logs.first

    expect(message).to eq('some info from wihtin a context')
  end
end

RSpec.describe 'Tag' do
  it 'runs with a specific tag' do
    expect(runs_with_tags.count).to eq(3)
    expect(runs_with_tags[0].parent.desc).to eq('should run with the tag')
    expect(runs_with_tags[1].parent.desc).to eq('should also run with tags')
    expect(runs_with_tags[2].parent.desc).to eq('should not run with this tag')
  end

  it 'runs with multiple tags' do
    expect(runs_with_multiple_tags.count).to eq(1)
    expect(runs_with_tags[0].parent.desc).to eq('should run with the tag')
  end

  it 'runs with different tags' do
    expect(runs_with_different_tags.count).to eq(3)
    expect(runs_with_tags[0].parent.desc).to eq('should run with the tag')
    expect(runs_with_tags[1].parent.desc).to eq('should also run with tags')
    expect(runs_with_tags[2].parent.desc).to eq('should not run with this tag')
  end

  it 'runs without a specific tag' do
    expect(runs_without_tag.count).to eq(2)
    expect(runs_with_tags[0].parent.desc).to eq('should run with the tag')
    expect(runs_with_tags[1].parent.desc).to eq('should also run with tags')
  end
end

