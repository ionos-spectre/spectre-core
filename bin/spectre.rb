#! /usr/bin/ruby

require 'yaml'
require 'ostruct'
require 'optparse'

require_relative '../lib/spectre'
require_relative '../lib/spectre/helpers/console'


DEFAULT_CONFIG = {
  'config_file' => './spectre.yml',
  'environment' => 'default',
  'specs' => [],
  'tags' => [],
  'colored' => true,
  'verbose' => false,
  'reporter' => 'Spectre::Reporter::Console',
  'logger' => 'Spectre::Logger::Console',
  'log_path' => './logs',
  'spec_patterns' => ['./specs/**/*.spec.rb'],
  'env_patterns' => ['./environments/**/*.env.yml'],
  # 'resource_paths' => ['./resources'],
  # 'helper_paths' => ['./helpers'],
  # 'conf_patterns' => ['./config/**/*.conf.rb'],
  # 'mixin_patterns' => ['./mixins/**/*.mixin.rb'],
  'modules' => [
    'spectre/helpers',
    'spectre/helpers/console',
    'spectre/reporter/console',
    'spectre/reporter/junit',
    'spectre/logger/console',
    'spectre/assertion',
    'spectre/http',
    'spectre/http/basic_auth',
  ],
}


cmd_options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = %{Spectre #{Spectre::VERSION}

Usage: spectre [command] [options]

Commands:
  list        List specs
  run         Run specs (default)

Specific options:}
  
  opts.on('-s spec1,spec2', '--specs spec1,spec2', Array, 'The specs to run') do |specs|
    cmd_options['specs'] = specs
  end

  opts.on('-t tag1,tag2', '--tags tag1,tag2', Array, 'Run only specs with give tags') do |tags|
    cmd_options['tags'] = tags
  end

  opts.on('-e env_name', '--env env_name', 'Name of the environment to load') do |env_name|
    cmd_options['environment'] = env_name
  end

  opts.on('-c file', '--config file', 'Config file to load') do |file_path|
    cmd_options['config_file'] = file_path
  end

  opts.on('--spec-pattern', Array, 'File pattern for spec files') do |spec_pattern|
    cmd_options['spec_patterns'] = spec_pattern
  end

  opts.on('--env-pattern', Array, 'File pattern for environment files') do |env_patterns|
    cmd_options['env_patterns'] = env_patterns
  end

  opts.on('--color', 'Enable colored output') do |colored|
    cmd_options['colored'] = colored
  end

  opts.on('-r name', '--reporter name', Array, 
    "The name of the reporter to use",
  ) do |reporter|
    cmd_options['reporter'] = reporter
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


SPEC_CFG = {}
SPEC_CFG.merge! DEFAULT_CONFIG

config_file = cmd_options['config_file'] || DEFAULT_CONFIG['config_file']

if File.exists? config_file
  file_options = YAML.load_file(config_file)
  SPEC_CFG.merge! file_options
end

SPEC_CFG.merge! cmd_options


###########################################
# Load Environment
###########################################


envs = {}

SPEC_CFG['env_patterns'].each do |pattern|
  Dir.glob(pattern).each do|f|
    spec_env = YAML.load_file(f)
    name = spec_env.delete('name') || 'default'
    envs[name] = spec_env
  end
end

env = envs[SPEC_CFG['environment']]
SPEC_CFG.merge! env if env


String.colored! if SPEC_CFG['colored']


###########################################
# Create Log Path
###########################################


log_path = SPEC_CFG['log_path']
if !File.directory? log_path
  Dir.mkdir(log_path)
end


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


Spectre.configure(SPEC_CFG)


###########################################
# Load Specs
###########################################


SPEC_CFG['spec_patterns'].each do |pattern|
  Dir.glob(pattern).each do|f|
    require_relative File.join(Dir.pwd, f)
  end
end


###########################################
# Execute Action
###########################################


if action == 'list'
  colors = [:blue, :magenta, :yellow, :green]

  exit 1 if Spectre::subjects.length == 0

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
  logger = Kernel.const_get(SPEC_CFG['logger'])
  reporter = Kernel.const_get(SPEC_CFG['reporter']).new

  runner = Spectre::Runner.new(Spectre.subjects, logger)
  run_infos = runner.run(SPEC_CFG['specs'], SPEC_CFG['tags'])

  reporter.report(run_infos)
end


if action == 'envs'
  exit 1 if envs.length == 0
  puts envs.pretty
end


if action == 'show'
  puts SPEC_CFG.pretty
end


if action == 'init'
  %w(environments logs specs).each do |dir_name|
    if !File.directory? dir_name
      Dir.mkdir(dir_name)
    end
  end
end