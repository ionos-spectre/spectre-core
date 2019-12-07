#! /usr/bin/ruby

require 'yaml'
require 'ostruct'
require 'optparse'

require_relative '../lib/spectre'


options = OpenStruct.new({
  config_file: './spectre.yml',
  spec_pattern: '**/*.spec.rb',
  env: 'default',
  verbose: false,
  colored: true,
  specs: [],
  tags: [],
})

opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: spectre.rb [options]'

  opts.separator ''
  opts.separator 'Specific options:'

  opts.on('-s spec1,spec2', '--specs spec1,spec2', Array, 'The specs to run') do |specs|
    options.specs = specs
  end

  opts.on('-t tag1,tag2', '--tags tag1,tag2', Array, 'Run only specs with give tags') do |tags|
    options.tags = tags
  end

  opts.on('--spec-pattern', 'File pattern for spec files') do |spec_pattern|
    options.spec_pattern = spec_pattern
  end

  opts.on('--[no]-colored', 'Enable colored output') do |colored|
    options.colored = colored
  end

  opts.separator ''
  opts.separator 'Common options:'

  opts.on_tail('-h', '--help', 'Print this help') do
    puts opts
    exit
  end
end.parse!

action = ARGV[0] || 'run'


# Start


if options.colored
  String.colored!
end

SPEC_CFG = YAML.load_file(options.config_file)
SPEC_ENV = YAML.load_file File.join(SPEC_CFG['env_path'], "#{options.env}.env.yml")


# Load Modules


SPEC_CFG['modules'].each do |mod_name|
  require_relative "../lib/#{mod_name}"
end


# Load Specs


Dir.glob(options.spec_pattern).each do|f|
  require_relative File.join(Dir.pwd, f)
end


# Execute Action


if action == 'list'
  Spectre::subjects.each do |subject|
    subject.specs.each do |spec|
      tags = spec.tags.map { |x| '#' + x }.join ' '
      puts "[#{spec.id}]".blue + " #{subject.desc} #{spec.desc} #{tags.cyan}"
    end
  end
end


if action == 'run'
  subjects = Spectre.run(options.specs, options.tags)
  Spectre.report(subjects)
end