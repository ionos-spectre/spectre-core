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
  'out_path' => './reports',
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
    'spectre/environment',
    'spectre/http',
    'spectre/http/basic_auth',
    'spectre/http/keystone',
    'spectre/ssh',
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
  show        Print current environment settings
  init        Initializes a new spectre project

Specific options:}

  opts.on('-s SPEC,SPEC', '--specs SPEC,SPEC', Array, 'The specs to run') do |specs|
    cmd_options['specs'] = specs
  end

  opts.on('-t TAG,TAG', '--tags TAG,TAG', Array, 'Run only specs with give tags') do |tags|
    cmd_options['tags'] = tags
  end

  opts.on('-e NAME', '--env NAME', 'Name of the environment to load') do |env_name|
    cmd_options['environment'] = env_name
  end

  opts.on('-c FILE', '--config FILE', 'Config file to load') do |file_path|
    cmd_options['config_file'] = file_path
  end

  opts.on('--spec-pattern PATTERN', Array, 'File pattern for spec files') do |spec_pattern|
    cmd_options['spec_patterns'] = spec_pattern
  end

  opts.on('--env-pattern PATTERN', Array, 'File pattern for environment files') do |env_patterns|
    cmd_options['env_patterns'] = env_patterns
  end

  opts.on('--no-color', 'Enable colored output') do |colored|
    cmd_options['colored'] = false
  end

  opts.on('-o PATH', '--out PATH', 'Output directory path') do |path|
    cmd_options['out_path'] = path
  end

  opts.on('-r NAME', '--reporter NAME', "The name of the reporter to use") do |reporter|
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
  Dir.chdir File.dirname(config_file)
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
# List specs
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
  reporter = Kernel.const_get(cfg['reporter']).new(cfg)

  specs = Spectre.specs(cfg['specs'], cfg['tags'])

  if specs.length == 0
    puts "no specs found in #{Dir.pwd}"
    exit 1
  end

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

DEFAULT_SPECTRE_CFG = %{log_path: ./logs
env_pattern: '**/*.env.yml'
spec_pattern: '**/*.spec.rb'
modules:
  - spectre/helpers
  - spectre/helpers/console
  - spectre/reporter/console
  - spectre/reporter/junit
  - spectre/logger/console
  - spectre/assertion
  - spectre/diagnostic
  - spectre/environment
  - spectre/http
  - spectre/http/basic_auth
  - spectre/http/keystone
  - spectre/ssh
}


DEFAULT_ENV_CFG = %{cert: &cert ./resources/<root_cert>.cer
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
    #   cert: *cert
# ssh:
#   <ssh_client_name>:
#     host: <hostname>
#     username: <username>
#     password: <password>
}

SAMPLE_SPEC = %[describe '<subject>' do
  it 'does some http requests', tags: [:sample] do
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
        "message": "Hello Spectre!"
      })
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'a message to exist' do
      response.json.message.should_not_be nil
    end
  end
end
]

DEFAULT_GITIGNORE = %[*.code-workspace
logs/
reports/
**/.failed
**/environments/*.env.yml
]

if action == 'init'
  DEFAULT_FILES = [
    ['./environments/default.env.yml', DEFAULT_ENV_CFG],
    ['./specs/sample.spec.rb', SAMPLE_SPEC],
    ['./spectre.yml', DEFAULT_SPECTRE_CFG],
    ['./.gitignore', DEFAULT_GITIGNORE],
  ]

  %w(environments logs specs).each do |dir_name|
    Dir.mkdir(dir_name) unless File.directory? dir_name
  end

  DEFAULT_FILES.each do |file, content|
    if not File.exists? file
      File.write(file, content)
  end
  end
end