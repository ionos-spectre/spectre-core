<div align="center">
  <img src="https://github.com/ionos-spectre/spectre-core/blob/develop/spectre_icon.png?raw=true" alt="IONOS Spectre" style="width:200px">
  <h2>IONOS Spectre</h2>
  <p>Describe Tests. Analyse Results. Understand What Happened.</p>
  <a href="https://github.com/ionos-spectre/spectre-core/actions/workflows/build.yml"><img src="https://github.com/ionos-spectre/spectre-core/actions/workflows/build.yml/badge.svg" alt="Build Status" /></a>
  <a href="https://github.com/ionos-spectre/spectre-core/actions/workflows/docker-publish.yml"><img src="https://github.com/ionos-spectre/spectre-core/actions/workflows/docker-publish.yml/badge.svg" alt="Docker Status" /></a>
  <a href="https://rubygems.org/gems/spectre-core"><img src="https://badge.fury.io/rb/spectre-core.svg" alt="Gem Version" /></a>
</div>

# Spectre

Spectre is a DSL and command line tool for test automation.

It is written in [Ruby](https://www.ruby-lang.org/de/) 
and inspired by the Unit-Test framework [rspec](https://rspec.info/).

This framework focuses on API behavior testing, rapid and flexible test development.


## Philosophy

> Code is documentation

The framework is designed for non-developers and to provide easy to read tests. 
When writing and reading tests, you should immediately understand what is going on.
This helps to debug test subjects and to better understand what and how it is tested.


## External Modules

| Module | Documentation |
| ------ | ------------- |
| `spectre/http` | https://github.com/ionos-spectre/spectre-http |
| `spectre/ftp` | https://github.com/ionos-spectre/spectre-ftp |
| `spectre/git` | https://github.com/ionos-spectre/spectre-git |
| `spectre/mysql` | https://github.com/ionos-spectre/spectre-mysql |
| `spectre/ssh` | https://github.com/ionos-spectre/spectre-ssh |
| `spectre/reporter/html` | https://github.com/ionos-spectre/spectre-reporter-html |
| `spectre/reporter/vstest` | https://github.com/ionos-spectre/spectre-reporter-vstest |
| `spectre/reporter/junit` | https://github.com/ionos-spectre/spectre-reporter-junit |


## Docker

There is a `Dockerfile` to build `spectre` Docker images.
To build a Docker image run

```bash
$ docker build -t spectre .
```

and then run with

```bash
$ docker run -t --rm -v "path/to/specs:/spectre" spectre [command] [options]
```


## Installation

To use the command line tool, Ruby has to be installed on your system. 

See [ruby-lang.org](https://www.ruby-lang.org/en/documentation/installation/) for installation instructions.

To install Ruby on windows, just use `winget`

```powershell
# Search for available Ruby versions
winget search ruby

# Install Ruby with dev kit
winget instal RubyInstallerTeam.RubyWithDevKit.3.4
```

Spectre is available as a Ruby *gem* from https://rubygems.org/

```bash
$ gem install spectre-core
```

or clone this repository and run

```bash
rake install
```

To test, if the tool is working, try one of the following commands.

```bash
$ spectre -h
$ spectre --version
```


## Quickstart

To create a minimal spectre project run the following command

```bash
$ spectre init
```

This will create a basic folder structure and generate some sample files.


## Creating a new project

Create a new project structure by executing
```bash
$ spectre init
```

This will create multiple empty directories and a `spectre.yml` config file.

| Directory/File | Description |
| -------------- | ----------- |
| `environments` | This directory should contain `**/*.env.yml` files. In these files, you can define environment variables, which can be accessed during a spec run. |
| `logs` | Logs will be placed in this folder |
| `reports` | This folder contains report files like the HTML report, which are created by `reporter` |
| `resources` | This folder can contain any files, which can be used in *spec* definitions. |
| `specs` | This is the folder, where all spec files should be placed. The standard file pattern is `**/*.spec.rb` |
| `spectre.yml` | This is `spectre`'s default config file. This file includes default file patterns and paths. Options in this file can be overwritten with command line arguments. |
| `.gitignore` | This `.gitignore` file contains files and directories, which should not be tracked by version control. If created manually, make sure your environment files are not tracked. |


### Spectre Config

The following properties can be set in your `spectre.yml`. 
Shown values are set by default.

See [Spectre::CONFIG](./lib/spectre.rb#L798-L817) for default values and available options.

All options can also be overridden with the command line argument `-p` or `--property`

```bash
$ spectre -p config_file=my_custom_spectre.yml -p "log_file=/var/log/spectre/spectre-<date>.log"
```

You can also create a global spectre config file with the options above. 
Create a file `.spectre` in your users home directory (`~/.spectre`) 
and set the options you like.


## Writing specs

To write automated tests, just open an editor of your choice and create a file named, 
for example `spooky.spec.rb` in the `specs` folder. Specs are structured in three levels. 
The *subject* defined by the keyword `describe`, the actual *specification* defined 
by the `it` keyword and one or more *assertions* or *expectations* described by `assert` or `expect`.
A *subject* can contain one or more *specs*.

Copy the following code into the file and save it

TODO: create example files and add link


## Listing specs

To list specs execute

```bash
$ spectre list
```

The output looks like this

```
[spooky-1] Spooky always has the right answer #simple
[spooky-2] Spooky does some strange things in the neighbourhood #scary
[spooky-3] Spooky only scares some people #scary #dangerous
```

The name in the brackets is an identifier for a *spec*. This can be used to run only specific *specs*.
Note that this ID can change, when more *specs* have been added.


## Advanced writing specs

Your project could consist of hundreds and thousand of *specs*. 
In order to easier maintain your project, it is recommended to 
place *specs* of a *subject* in different `*.spec.rb` files and folders, 
grouped by a specific context. A *subject* can be described in multiple files.

For example, when writing *specs* for a REST API, the *specs* could be grouped 
by the APIs *resources* in different folders, and their *operations* in different files.

Specs of a RPC API can be grouped by its functions.

Our *Hollow API* has two resources *ghosts* and *monsters*. 
Each resource can be *created*, *read*, *updated* and *deleted*. 
The project structure could then look something like this:

```
hollow_webapi
+-- environments
|   +-- development.env.rb
|   +-- development.env.secret.rb
|   +-- staging.env.rb
|   +-- staging.env.secret.rb
|   +-- production.env.rb
|   +-- production.env.secret.rb
+-- logs
+-- specs
|   +-- ghosts
|   |   +-- create.spec.rb
|   |   +-- read.spec.rb
|   |   +-- update.spec.rb
|   |   +-- delete.spec.rb
|   |   +-- spook.spec.rb
|   +-- monsters
|       +-- create.spec.rb
|       +-- read.spec.rb
|       +-- update.spec.rb
|       +-- delete.spec.rb
+-- spectre.yaml
```

### Mixins `spectre/mixin`

You can define reusable specs by using mixins. Create a `.mixin.rb` file 
in the mixin directory (default: `mixins`)

```ruby
mixin 'check health' do |http_name| # the mixin can be parameterized
  http http_name do
    auth 'basic'
    method 'GET'
    path 'health'
  end

  expect 'the response code to be 200' do
    response.code.should be 200
  end

  expect 'the status to be ok' do
    response.json.status.should be 'Ok'
  end

  response
end
```

and add this mixin to any spec with the `run`, `step` or `also` function.

```ruby
describe 'Hollow API' do
  it 'checks health', tags: [:health] do
    also 'check health', with: ['dummy_api'] # pass mixin parameter as value list
  end
end
```

Like every ruby block or function, a mixin has a return value (the last expression in the `do` block)
If the return value is a `Hash`, it will be converted to an `OpenStruct` for better value access.

```ruby
mixin 'spooky stuff' do
  # spook around

  { say: 'Boo!' }
end
```

This can be used like so:

```ruby
describe 'Hollow API' do
  it 'is scary' do
    result = run 'spooky stuff'

    expect 'some spooky things' do
      result.say.should be 'Boo!'
    end
  end
end
```

You can pass one or more parameters to a mixin run. When passing one `Hash` to the mixin, 
it will be converted to an `OpenStruct` for easier access.

```ruby
mixin 'spook around' do |params|
  required params, :boo, :rawrrr
  optional params, :light

  [...]
end
```

When required keys are missing, an `ArgumentError` will be raised.
`optional` will only log the optional keys to the spectre log for debugging purposes.


## Development

### Modules

```ruby
module Spectre
  module MyModule
    # Define a default config for your module to operate on
    DEFAULT_CONFIG = {
      'message' => 'Hello',
    }

    # Create a class to provide some function
    # for manipulating the config at runtime
    # in scope of your module
    class Greetings
      def initialize config
        @config = config
      end

      # Provide some function to manipulate the config ad runtime
      def message text
        @config['message'] = text
      end
    end

    class << self
      # Load a specific config section, when used with Spectre
      # otherwise initialize an empty `Hash`
      @@config = defined?(Spectre::CONFIG) ? Spectre::CONFIG['my_module'] || {} : {}

      # Implement a logger with lazy loading, as the `Spectre.logger`
      # will be initialized *after* the module is loaded
      def logger
        @@logger ||= defined?(Spectre.logger) ? Spectre.logger : Logger.new($stdout)
      end

      def greetings name, &block
        # Get the specific options with given name
        # from the config hash, if the given name is present
        # This takes effect when the module is used with Spectre
        if @@config.key? name
          config = @@config[name]
        else
          # Otherwise use an empty hash, when module is used as standalone
          # or there is no config present for this name
          config = {}
        end

        # Instanciate you configuration class
        # and call `instance_eval` to "expose" those function
        Greetings.new(config).instance_eval(&block)

        # Merge the default config with the given one
        # in order to ensure all required values are present
        config = DEFAULT_CONFIG.merge(config)

        # Do your logic with the config
        puts "#{config['message']} #{config['name']}!"
      end
    end
  end
end

# Expose you module function to the wild, so it can be used anywhere
# without prefixing the name of you module
# Be aware that this can override existing functions
%i{greetings}.each do |method|
  Kernel.define_method(method) do |*args, &block|
    Spectre::MyModule.send(method, *args, &block)
  end
end
```

The module can then be used standalone

```ruby
greetings 'World' do
  message 'Konnichiwa'
end
# Konnichiwa World!

greetings 'World'
# Hello World!
```

or as an Spectre module

`default.env.yml`
```yml
my_module:
  first_greeting:
    name: World
```

`greeting.spec.rb`
```ruby
describe 'Greeting' do
  it 'greets with a name' do
    greetings 'first_greeting' do
      message 'Ohayo'
    end
    # Ohayo World!

    greetings 'first_greeting'
    # Hello World!
  end
end
```
