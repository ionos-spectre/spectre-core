# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'rdoc/task'

task default: %i[style test doc build]

RuboCop::RakeTask.new(:style) do |task|
  task.plugins << 'rubocop-rake'
end

RSpec::Core::RakeTask.new(:test)

RDoc::Task.new(:doc) do |rdoc|
  rdoc.main = 'main.rdoc'
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include('main.rdoc', 'lib/**/*.rb')
end
