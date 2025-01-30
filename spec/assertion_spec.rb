require_relative '../lib/assertion'

RSpec.describe 'Assertion' do
  before do
    @console_out = StringIO.new
    @log_out = StringIO.new

    Spectre
      .setup({
        'log_file' => @log_out,
        'stdout' => @console_out,
      })
  end

  context 'equal check' do
    [
      [42, 42],
      ['42', '42'],
    ].each do |actual, expected|
      it 'evaluates positive' do
        evaluation = actual
          .to Spectre::Assertion
          .be expected

        result = evaluation.run

        expect(result).to be_truthy
        expect(evaluation.to_s).to eq("to be #{expected.inspect}")
      end
    end

    it 'evaluates negative' do
      evaluation = 666
        .to Spectre::Assertion
        .be 42

      result = evaluation.run

      expect(result).to be_falsy
      expect(evaluation.to_s).to eq('to be 42')
    end

    it 'negates' do
      evaluation = 42
        .not Spectre::Assertion
        .to Spectre::Assertion
        .be 666

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('not to be 666')
    end

    it 'negates negative' do
      evaluation = 666
        .not Spectre::Assertion
        .to Spectre::Assertion
        .be 666

      result = evaluation.run

      expect(result).to be_falsy
      expect(evaluation.to_s).to eq('not to be 666')
    end

    it 'accepts either the one or the other value' do
      evaluation = 42
        .to Spectre::Assertion
        .be 24.or 42

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('to be 24 or 42')
    end
  end

  context 'contain check' do
    it 'evaluates positive' do
      evaluation = [42, 'foo']
        .to Spectre::Assertion
        .contain 42

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('to contain 42')
    end

    it 'evaluates negative' do
      evaluation = [42, 'foo']
        .to Spectre::Assertion
        .contain 666

      result = evaluation.run

      expect(result).to be_falsy
      expect(evaluation.to_s).to eq('to contain 666')
    end

    it 'accepts either the one or the other value' do
      evaluation = [42, 'foo', 'bar']
        .to Spectre::Assertion
        .contain 42.or 'buff'

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('to contain 42 or "buff"')
    end

    it 'accepts two values' do
      evaluation = [42, 'foo', 'bar']
        .to Spectre::Assertion
        .contain 42.and 'foo'

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('to contain 42 and "foo"')
    end

    it 'accepts a group of values' do
      evaluation = [42, 'foo', 'bar']
        .to Spectre::Assertion
        .contain 24.or 42.and 'foo'

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('to contain 24 or 42 and "foo"')
    end

    it 'negates' do
      evaluation = [42, 'foo', 'bar']
        .not Spectre::Assertion
        .to Spectre::Assertion
        .contain 'buff'

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('not to contain "buff"')
    end

    it 'negates with multiple values' do
      evaluation = [42, 'foo', 'bar']
        .not Spectre::Assertion
        .to Spectre::Assertion
        .contain 'buff'.or 'bar'

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('not to contain "buff" or "bar"')
    end

    it 'negates with multiple values' do
      evaluation = [42, 'foo', 'bar']
        .not Spectre::Assertion
        .to Spectre::Assertion
        .contain 'buff'.and 666

      result = evaluation.run

      expect(result).to be_truthy
      expect(evaluation.to_s).to eq('not to contain "buff" and 666')
    end

    context 'match' do
      it 'evaluates positive' do
        evaluation = 'this is a text'
          .to Spectre::Assertion
          .match(/this .*/)

        result = evaluation.run

        expect(result).to be_truthy
        expect(evaluation.to_s).to eq('to match /this .*/')
      end

      it 'evaluates negative' do
        evaluation = 'this is a text'
          .to Spectre::Assertion
          .match(/not this .*/)

        result = evaluation.run

        expect(result).to be_falsy
        expect(evaluation.to_s).to eq('to match /not this .*/')
      end

      it 'evaluates either one or the other' do
        evaluation = 'this is a text'
          .to Spectre::Assertion
          .match(/this .*/.or(/that/))

        result = evaluation.run

        expect(result).to be_truthy
        expect(evaluation.to_s).to eq('to match /this .*/ or /that/')
      end

      it 'evaluates both' do
        evaluation = 'this is a text'
          .to Spectre::Assertion
          .match(/.* is/.and(/a text/))

        result = evaluation.run

        expect(result).to be_truthy
        expect(evaluation.to_s).to eq('to match /.* is/ and /a text/')
      end
    end
  end

  context 'empty check' do
    [{}, [], nil].each do |actual|
      it 'evaluates positive' do
        evaluation = actual
          .to Spectre::Assertion
          .be_empty

        result = evaluation.run

        expect(result).to be_truthy
        expect(evaluation.to_s).to eq('to be empty')
      end
    end

    [1, 'foo', [1, 2], {foo: 'bar'}].each do |actual|
      it 'evaluates negative' do
        evaluation = actual
          .to Spectre::Assertion
          .be_empty

        result = evaluation.run

        expect(result).to be_falsy
        expect(evaluation.to_s).to eq('to be empty')
      end
    end
  end

  it 'creates an assertion failure' do
    value = 666
    context = Spectre::Assertion.assert value.to Spectre::Assertion.be 42

    expect(context.desc).to eq('assert value to be 42')
    expect(context.failures.count).to eq(1)

    failure = context.failures.first

    expect(failure.message).to eq('expected value to be 42, but got 666')
    expected_filepath = __FILE__.sub(Dir.pwd, '.')
    expect(failure.file).to eq(expected_filepath)
    expect(failure.line).not_to eq(nil)
    expect(failure.to_s).to start_with('expected value to be 42, but got 666')
    expect(failure.to_s).to match(" - in #{expected_filepath}:\\d+")

    @console_out.rewind
    output = @console_out.read
    expect(output).to eq("assert value to be 42#{'.' * 59}#{'[failed]'.red}\n")

    @log_out.rewind
    log = @log_out.readlines
    expect(log.count).to eq(1)
    expect(log.first).to end_with("assert value to be 42 - failed\n")
  end
end
