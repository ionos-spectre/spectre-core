#! /usr/bin/ruby

require 'yaml'
require 'ostruct'
require 'optparse'
require 'fileutils'

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
  'modules' => [
    'spectre/helpers',
    'spectre/helpers/console',
    'spectre/reporter/console',
    'spectre/reporter/junit',
    'spectre/logger/console',
    'spectre/assertion',
    'spectre/diagnostic',
    'spectre/http',
    'spectre/http/basic_auth',
    'spectre/http/keystone',
    # 'spectre/database/postgres',
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

  opts.on('-r name', '--reporter name', Array, "The name of the reporter to use") do |reporter|
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


cfg = {}
cfg.merge! DEFAULT_CONFIG

config_file = cmd_options['config_file'] || DEFAULT_CONFIG['config_file']

if File.exists? config_file
  file_options = YAML.load_file(config_file)
  cfg.merge! file_options
end

cfg.merge! cmd_options


###########################################
# Load Environment
###########################################


envs = {}

cfg['env_patterns'].each do |pattern|
  Dir.glob(pattern).each do|f|
    spec_env = YAML.load_file(f)
    name = spec_env.delete('name') || 'default'
    envs[name] = spec_env
  end
end

env = envs[cfg['environment']]
cfg.merge! env if env


String.colored! if cfg['colored']


###########################################
# Create Log Path
###########################################


log_path = cfg['log_path']
FileUtils.rm_rf(log_path) if File.directory? log_path
Dir.mkdir(log_path)


###########################################
# Load Modules
###########################################


cfg['modules'].each do |mod|
  if !File.exists? mod
    require_relative File.join('../lib', mod)
  else
    require_relative mod
  end
end

require 'date'
require 'json'


Spectre.configure(cfg)


###########################################
# Load Specs
###########################################


cfg['spec_patterns'].each do |pattern|
  Dir.glob(pattern).each do|f|
    require_relative File.join(Dir.pwd, f)
  end
end


###########################################
# Execute Action
###########################################


if action == 'list'
  colors = [:blue, :magenta, :yellow, :green]
  specs = Spectre.specs(cfg['specs'], cfg['tags'])

  exit 1 if specs.length == 0

  counter = 0

  specs.group_by { |x| x.subject }.each do |subject, spec_group|
    spec_group.each do |spec|
      tags = spec.tags.map { |x| '#' + x.to_s }.join ' '
      desc = "#{subject.desc} #{spec.desc}"
      desc += ' ' + spec.context.desc if spec.context.desc
      puts "[#{spec.name}]".send(colors[counter % colors.length]) + " #{desc} #{tags.cyan}"
    end

    counter += 1
  end
end


###########################################
# Run
###########################################


if action == 'run'
  logger = Kernel.const_get(cfg['logger'])
  reporter = Kernel.const_get(cfg['reporter']).new

  specs = Spectre.specs(cfg['specs'], cfg['tags'])

  exit 1 if specs.length == 0

  runner = Spectre::Runner.new(logger)
  run_infos = runner.run(specs)

  reporter.report(run_infos)
end


###########################################
# Envs
###########################################


if action == 'envs'
  exit 1 if envs.length == 0
  puts envs.pretty
end


###########################################
# Show
###########################################


if action == 'show'
  puts cfg.pretty
end


###########################################
# Init
###########################################

DEFAULT_ENV_CFG = %{pukiroot: &pukiroot ./resources/<root_cert>.cer
http:
  <http_client_name>:
    base_url: http://localhost:5000/api/v1/
    # basic_auth:
    #   username: <username>
    #   password: <password>
    # keystone:
    #   url: https://<keystone_url>/main/v3/
    #   username: <username>
    #   password: <password>
    #   project: <project>
    #   domain: <domain>
    #   cert: *pukiroot
# ssh:
#   <ssh_client_name>:
#     host: <hostname>
#     username: <username>
#     password: <password>
}

SAMPLE_SPEC = %[describe '<subject>' do
  it 'do some http requests', tags: [:sample] do
    log 'doing some http request'

    http '<http_client_name>' do
      auth 'basic_auth'
      # auth 'keystone'
      method 'GET'
      path 'path/to/resource'
      param 'id', 4295118773
      param 'foo', 'bar'
      header 'X-Correlation-Id', '4c2367b1-bfee-4cc2-bdc5-ed17a6a9dd4b'
      header 'Range', 'bytes=500-999'
      json({
        message: 'Hello Spectre!'
      })
    end

    expect 'the response code to be 200' do
      response.code.should_be '200'
    end

    expect 'a message to exist' do
      response.json.message.should_not_be nil
    end
  end
end
]

if action == 'init'
  %w(environments logs specs).each do |dir_name|
    Dir.mkdir(dir_name) unless File.directory? dir_name
  end

  default_env_file = './environments/default.env.yml'

  if not File.exists? default_env_file
    File.write(default_env_file, DEFAULT_ENV_CFG)
  end

  sample_spec_file = './specs/sample.spec.rb'

  if not File.exists? sample_spec_file
    File.write(sample_spec_file, SAMPLE_SPEC)
  end
end