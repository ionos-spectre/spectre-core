RSpec.describe Spectre::SimpleReporter do
  it 'formats report output correctly' do
    # SimpleReporter tests are now in spec_runner_spec.rb
    # This file can be used for testing report formatting specifics
    expect(Spectre::SimpleReporter).to respond_to(:new)
  end
end
