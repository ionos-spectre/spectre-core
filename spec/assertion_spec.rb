require_relative '../lib/spectre/assertion'

RSpec.describe Spectre::Assertion do
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
        evaluation = actual.to Spectre::Assertion.be expected

        expect(evaluation.failure).to be_nil
        expect(evaluation.to_s).to eq("actual to be #{expected.inspect}")
      end
    end

    it 'evaluates negative' do
      value = 666
      evaluation = value.to Spectre::Assertion.be 42

      expect(evaluation.failure).to eq('got 666')
      expect(evaluation.to_s).to eq('value to be 42')
    end

    it 'negates' do
      value = 42
      evaluation = value.not Spectre::Assertion.to Spectre::Assertion.be 666

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value not to be 666')
    end

    it 'negates negative' do
      value = 666
      evaluation = value.not Spectre::Assertion.to Spectre::Assertion.be 666

      expect(evaluation.failure).to eq('it does not')
      expect(evaluation.to_s).to eq('value not to be 666')
    end

    it 'accepts either the one or the other value' do
      value = 42
      evaluation = value.to Spectre::Assertion.be 24.or 42

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value to be 24 or 42')
    end
  end

  context 'contain check' do
    it 'evaluates positive' do
      value = [42, 'foo']
      evaluation = value.to Spectre::Assertion.contain 42

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value to contain 42')
    end

    it 'evaluates negative' do
      value = [42, 'foo']
      evaluation = value.to Spectre::Assertion.contain 666

      expect(evaluation.failure).to eq('got [42, "foo"]')
      expect(evaluation.to_s).to eq('value to contain 666')
    end

    it 'accepts either the one or the other value' do
      value = [42, 'foo', 'bar']
      evaluation = value.to Spectre::Assertion.contain 42.or 'buff'

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value to contain 42 or "buff"')
    end

    it 'accepts two values' do
      value = [42, 'foo', 'bar']
      evaluation = value.to Spectre::Assertion.contain 42.and 'foo'

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value to contain 42 and "foo"')
    end

    it 'accepts a group of values' do
      value = [42, 'foo', 'bar']
      evaluation = value.to Spectre::Assertion.contain 24.or 42.and 'foo'

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value to contain 24 or 42 and "foo"')
    end

    it 'negates' do
      value = [42, 'foo', 'bar']
      evaluation = value.not Spectre::Assertion.to Spectre::Assertion.contain 'buff'

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value not to contain "buff"')
    end

    it 'negates with multiple values' do
      value = [42, 'foo', 'bar']
      evaluation = value.not Spectre::Assertion.to Spectre::Assertion.contain 'buff'.or 'bar'

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value not to contain "buff" or "bar"')
    end

    it 'negates with multiple values' do
      value = [42, 'foo', 'bar']
      evaluation = value.not Spectre::Assertion.to Spectre::Assertion.contain 'buff'.and 666

      expect(evaluation.failure).to be_nil
      expect(evaluation.to_s).to eq('value not to contain "buff" and 666')
    end

    context 'match' do
      it 'evaluates positive' do
        value = 'this is a text'
        evaluation = value.to Spectre::Assertion.match(/this .*/)

        expect(evaluation.failure).to be_nil
        expect(evaluation.to_s).to eq('value to match /this .*/')
      end

      it 'evaluates negative' do
        value = 'this is a text'
        evaluation = value.to Spectre::Assertion.match(/not this .*/)

        expect(evaluation.failure).to eq("got #{value.inspect}")
        expect(evaluation.to_s).to eq('value to match /not this .*/')
      end

      it 'evaluates either one or the other' do
        value = 'this is a text'
        evaluation = value.to Spectre::Assertion.match(/this .*/.or(/that/))

        expect(evaluation.failure).to be_nil
        expect(evaluation.to_s).to eq('value to match /this .*/ or /that/')
      end

      it 'evaluates both' do
        value = 'this is a text'
        evaluation = value.to Spectre::Assertion.match(/.* is/.and(/a text/))

        expect(evaluation.failure).to be_nil
        expect(evaluation.to_s).to eq('value to match /.* is/ and /a text/')
      end
    end
  end

  context 'empty check' do
    [{}, [], nil].each do |actual|
      it 'evaluates positive' do
        evaluation = actual.to Spectre::Assertion.be_empty

        expect(evaluation.failure).to be_nil
        expect(evaluation.to_s).to eq('actual to be empty')
      end
    end

    [1, 'foo', [1, 2], {foo: 'bar'}].each do |actual|
      it 'evaluates negative' do
        evaluation = actual.to Spectre::Assertion.be_empty

        expect(evaluation.failure).to eq("got #{actual.inspect}")
        expect(evaluation.to_s).to eq('actual to be empty')
      end
    end
  end
end
