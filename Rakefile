# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rdoc/task'

task default: %i[test doc build]

RSpec::Core::RakeTask.new(:test)

RDoc::Task.new(:doc) do |rdoc|
  rdoc.main = 'README.rdoc'
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include('README.rdoc', 'lib/**/*.rb')
end
