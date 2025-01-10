RSpec.describe 'Self Test' do
  runs = Spectre
    .setup({
      'config_file' => File.join(File.dirname(__FILE__), 'spectre.yml'),
      'stdout' => StringIO.new,
    })
    .run
    .select { |run| run.parent.is_a? Spectre::Specification }

  # Test successful runs
  runs
    .select { |run| run.parent.tags.include?(:success) }
    .each do |run|
      it run.parent.desc do
        expect(run.error).to eq(nil)
        expect(run.failures.count).to eq(0)
      end
    end

  # Test failing runs
  runs
    .select { |run| run.parent.tags.include?(:fail) }
    .each do |run|
      it run.parent.desc do
        expect(run.error).to eq(nil)
        expect(run.failures.count).not_to eq(0)
        expect(run.failures.all? { |x| x.is_a? Spectre::Failure }).to be_truthy
      end
    end

  # Test error runs
  runs
    .select { |run| run.parent.tags.include?(:error) }
    .each do |run|
      it run.parent.desc do
        expect(run.failures.count).to eq(0)
        expect(run.error).not_to eq(nil)
        expect(run.error.message).to eq('Oops!')
      end
    end
end
