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
  reporter: 'Spectre::Reporter::Console',
})

opt_parser = OptionParser.new do |opts|
  opts.banner = %{Spectre #{Spectre::VERSION}

Usage: spectre [command] [options]

Commands:
  list        List specs
  run         Run specs (default)

Specific options:}
  
  opts.on('-s spec1,spec2', '--specs spec1,spec2', Array, 'The specs to run') do |specs|
    options.specs = specs
  end

  opts.on('-t tag1,tag2', '--tags tag1,tag2', Array, 'Run only specs with give tags') do |tags|
    options.tags = tags
  end

  opts.on('--spec-pattern', 'File pattern for spec files') do |spec_pattern|
    options.spec_pattern = spec_pattern
  end

  opts.on('--color', 'Enable colored output') do |colored|
    options.colored = colored
  end

  opts.on('-r name', '--reporter name', Array, 
    "The name of the reporter to use", 
    "(default: #{options.reporter})"
  ) do |reporter|
    options.reporter = reporter
  end

  opts.separator "\nCommon options:"

  opts.on_tail('--version', 'Print current installed version') do
    puts Spectre::VERSION
    exit
  end

  opts.on_tail('-h', '--help', 'Print this help') do
    puts opts
    exit
  end
end.parse!


action = ARGV[0] || 'run'

###########################################
# Load Config
###########################################

SPEC_CFG = YAML.load_file(options.config_file)

###########################################
# Load Environment
###########################################

envs = {}

Dir.glob(SPEC_CFG['env_pattern']).each do|f|
  spec_env = YAML.load_file(f)
  name = spec_env['name'] || 'default'
  envs[name] = spec_env
end

SPEC_ENV = envs[options.env]

###########################################
# Load Modules
###########################################

SPEC_CFG['modules'].each do |mod|
  if !File.exists? mod
    require_relative File.join('../lib', mod)
  else
    require_relative mod
  end
end

###########################################
# Load Specs
###########################################

Dir.glob(SPEC_CFG['spec_pattern'] || options.spec_pattern).each do|f|
  require_relative File.join(Dir.pwd, f)
end

###########################################
# Execute Action
###########################################

String.colored! if options.colored


if action == 'list'
  colors = [:blue, :magenta, :yellow, :green]
  counter = 0

  Spectre::subjects.each do |subject|
    subject.specs.each do |spec|
      tags = spec.tags.map { |x| '#' + x.to_s }.join ' '
      puts "[#{spec.id}]".send(colors[counter % colors.length]) + " #{subject.desc} #{spec.desc} #{tags.cyan}"
    end

    counter += 1
  end
end


if action == 'run'
  reporter = Kernel.const_get(options.reporter).new
  run_infos = Spectre.run(options.specs, options.tags)
  reporter.report(run_infos)
end