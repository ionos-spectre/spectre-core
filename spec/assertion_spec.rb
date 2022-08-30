require 'spectre/assertion'

RSpec.describe 'spectre/assertion' do
  it 'evaluates single assertions' do

    42.should_be 42

    expect do
      666.should_be 42

    end.to raise_error(Spectre::Assertion::AssertionFailure)
  end

  it 'evaluates complex assertions' do

    42.should_be 42.or 12
    12.should_be 42.or 12

    [1, 2, 3].should_contain 1.or 2
    [2, 3, 4].should_contain 1.or 2.and 3

    expect do
      [3, 4].should_contain 1.or 2.and 3
    end.to raise_error(Spectre::Assertion::AssertionFailure)

  end
end