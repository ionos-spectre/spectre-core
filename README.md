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

`spectre` is available as a docker image. Just run your *specs* 
in a Docker container with

```bash
$ docker run -t --rm -v "path/to/specs:/spectre" cneubauer/spectre [command] [options]
```


## Installation

To use the command line tool, Ruby has to be installed on your system. 
To install Ruby on Debian or Ubuntu run:

```bash
$ sudo apt install ruby-full
```

For other linux distributions see [ruby-lang.org](https://www.ruby-lang.org/en/documentation/installation/).

To install Ruby on windows, just use `winget`

```powershell
# Search for available Ruby versions
winget search ruby

# Install Ruby with dev kit
winget instal RubyInstallerTeam.RubyWithDevKit.3.2
```

Spectre is available as a Ruby *gem* from https://rubygems.org/

```bash
$ sudo gem install spectre-core
```

or clone this repository and run

```bash
rake install
```

or just clone this repository and create a symlink to `exe/spectre`

```bash
ln -s /path/to/spectre-core/exe/spectre /home/some_user/.local/bin/spectre # or some other location in your PATH
```

To test, if the tool is working, try one of the following commands.

```bash
$ spectre -h
$ spectre --version
```


### Troubleshoot

When getting an error message, like the one below, 
you have to install `bundler` first by running `sudo gem install bundler`.

```
$ sudo rake install --trace
rake aborted!
LoadError: cannot load such file -- bundler/gem_tasks
/usr/lib/ruby/2.5.0/rubygems/core_ext/kernel_require.rb:59:in `require'
/usr/lib/ruby/2.5.0/rubygems/core_ext/kernel_require.rb:59:in `require'
/home/spectre/spectre-ruby/Rakefile:1:in `<top (required)>'
/usr/lib/ruby/vendor_ruby/rake/rake_module.rb:29:in `load'
/usr/lib/ruby/vendor_ruby/rake/rake_module.rb:29:in `load_rakefile'
/usr/lib/ruby/vendor_ruby/rake/application.rb:703:in `raw_load_rakefile'
/usr/lib/ruby/vendor_ruby/rake/application.rb:104:in `block in load_rakefile'
/usr/lib/ruby/vendor_ruby/rake/application.rb:186:in `standard_exception_handling'
/usr/lib/ruby/vendor_ruby/rake/application.rb:103:in `load_rakefile'
/usr/lib/ruby/vendor_ruby/rake/application.rb:82:in `block in run'
/usr/lib/ruby/vendor_ruby/rake/application.rb:186:in `standard_exception_handling'
/usr/lib/ruby/vendor_ruby/rake/application.rb:80:in `run'
/usr/bin/rake:27:in `<main>'
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
| `environments` | This directory should contain `**/*_env.yml` files. In these files, you can define environment variables, which can be accessed during a spec run. |
| `logs` | Logs will be placed in this folder |
| `reports` | This folder contains report files like the HTML report, which are created by `reporter` |
| `resources` | This folder can contain any files, which can be used in *spec* definitions. |
| `specs` | This is the folder, where all spec files should be placed. The standard file pattern is `**/*.spec.rb` |
| `spectre.yml` | This is `spectre`'s default config file. This file includes default file patterns and paths. Options in this file can be overwritten with command line arguments. |
| `.gitignore` | This `.gitignore` file contains files and directories, which should not be tracked by version control. If created manually, make sure your environment files are not tracked. |


### Spectre Config

The following properties can be set in your `spectre.yml`. 
Shown values are set by default.

```yml
config_file: "./spectre.yml"
environment: default
specs: []
tags: []
verbose: false
log_file: "./logs/spectre_<date>.log"
debug: true
out_path: "./reports"
secure_keys: # Will be used when outputting test results or logs
  - password
  - secret
  - token
  - secure
  - authorization
spec_patterns:
  - "**/*.spec.rb"
mixin_patterns:
  - "../common/mixins/**/*.mixin.rb"
  - "./mixins/**/*.mixin.rb"
env_patterns:
  - "./environments/**/*.env.yml"
env_partial_patterns:
  - "./environments/**/*.env.secret.yml"
resource_paths:
  - "../common/resources"
  - "./resources"
modules: # Modules to require by default. Use `include` and `exclude` to modify this list without declaring explicit module list
  - spectre/helpers
  - spectre/reporter/console
  - spectre/logging/console
  - spectre/logging/file
  - spectre/assertion
  - spectre/diagnostic
  - spectre/environment
  - spectre/mixin
  - spectre/bag
  - spectre/http
  - spectre/http/basic_auth
  - spectre/http/keystone
  - spectre/resources
include: [] # Explicitly include modules
exclude: [] # Explicitly exclude modules
```

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
by the `it` keyword and one or more *expectations* described by the `expect` keyword. 
A *subject* can contain one or more *specs*.

Copy the following code into the file and save it

```ruby
def scare_people
  'Ahhhhhh!'
end

describe 'Spooky' do
  it 'always has the right answer', tags: [:simple] do

    log 'starting to do some calculations'

    the_answer = 42

    expect 'the answer to be 42' do
      the_answer.should be 42
    end
  end

  it 'does some strange things in the neighbourhood', with: ['sword', 'dagger'], tags: [:scary] do |data|
    # This spec will be run two times. First time with data=sword, second time with data=dagger

    expect "some action with #{data}" do
      hack_and_slay(data)
    end

    expect 'some ghosts in the streets' do
      fail_with 'no ghosts'
    end
  end

  it 'only scares some people', tags: [:scary, :dangerous, :spooky] do
    cry = scare_people()

    raise 'town was destroyed instead'

    expect 'the cry to be scary' do
      cry.should be 'Ahhhhhh!'
    end
  end

  context 'at midnight' do
    it 'only scares some people', tags: [:scary, :dangerous] do
      cry = scare_people()

      expect 'the cry to be scary' do
        cry.should be 'Ahhhhhh!'
      end
    end
  end
end
```


### Subject

A *subject* is the top level description block of a test suite. 
A *subject* can be anything that groups functionality, e.g. some REST API, 
or an abstract business domain/process like *Order Process*.

A *subject* is described by the `describe` function, and can contain many `context`

```ruby
describe 'Hollow API' do
  # Add context here
end
```

> One *subject* can be split into multiple files. Note hat every `describe` call 
> creates a new `context` and can contain its own `setup` and `teardown` 
> blocks (more about `setup` and `teardown` see below).


### Context

A *context* groups one or more *specifications* and can add an additional description layer.
The description is optional. Within a *context*, there are 4 additional blocks available.

A *context* can be created with

```
context <description> do

end
```

| Block | Description |
| -------- | ----------- |
| `setup` | Runs once at the **beginning** of the *context*. It can be used to create some specific state for tests in this context. Instance variables created in this block are available within the `teardown` block. |
| `teardown` | Runs once at the **end** of the *context*. This block is ensured to run, even on unexpected errors. It usually contains some logic to restore a previous state. |
| `before` | Runs **before every** *specification* in this *context*. Use this block to create new resources/values on every run. Values can be made accessible for runs by setting instance variables `@foo = 'bar'`. |
| `after` | Runs **after every** *specification* in this *context*. This block is ensured to run, even on unexpected errors. It usually contains some cleanup logic for every run. |

```ruby
describe 'Hollow API' do
  context 'at midnight' do
    setup do
      # Runs once at the beginning in this context
      @previous_clock = get_clock()
      set_clock('00:00')
    end

    teardown do
      # Runs once at the end in this context
      set_clock(@previous_clock)
    end

    before do
      # Runs before every `it` block in this context
      @house = build_a_spooky_house()
    end

    after do
      # Runs after every `it` block in this context
      destroy_building(@house)
    end
  end
end
```

The *description* is optional. If omitted, all blocks in this context will 
be added to the main *context*. Blocks in the main context can also 
be defined in the *subject* directly.

```ruby
describe 'Hollow API' do
  setup do
  end

  teardown do
  end

  before do
  end

  after do
  end
end
```

> `setup`, `teardown`, `before` and `after` can be used multiple times within a context.
> These block will be executed in the provided order.


### Specification

*Specifications* or *specs* define the actual tests and will be executed, 
when a test run is started. These blocks will be defined within a *context* block.

```
it <description> do

end
```

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    # Do some API calls or whatever here
  end

  context 'at midnight' do
    it 'sends out spooky ghosts' do
      # Do some API calls or whatever
    end
  end
end
```

*Spec* blocks contain Ruby code and one or multiple *expectations*.


### Expectation

*Expectations* are defined within a *spec*. These blocks are description blocks 
like `describe`, `context` and `it`, but will be evaluated at runtime.

*Expectation* are fulfilled, when the code in this block runs without any errors. 
Unexpected runtime exceptions will generate an `error` status and will end 
the *spec* run and continue with the next *spec*.

Raising an `ExpectationFailure` exception in this block, will end up in 
a `failed` status and also end the *spec* run.


```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'some ghosts in the neighborhood' do
      raise ExpectationFailure, 'no ghosts'
    end
  end

  context 'at midnight' do
    it 'sends out spooky ghosts' do
      expect 'some ghosts in the neighborhood' do
        raise 'Opps! The house was accidently destroyed!'
      end
    end
  end
end
```

You don't have to raise an `ExpectationFailure` exception manually. 
Within an `expect` block, there is the `fail_with <message>` function available. 
This function raises an `ExpectationFailure` with the given message.

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'some ghosts in the neighborhood' do
      fail_with 'no ghosts'
    end
  end
end
```

The status of an `expect` can be either `failed` or `error`.

If you don't want the run to end, when an error or failure occurs, 
wrap the code with `observe`.
The result is available with `success?`. The value is `true`, 
if no exception occurred within the block.

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    observe 'the neighborhood' do
      expect 'some ghosts in the neighborhood' do
        fail_with 'no ghosts'
      end
    end

    log 'expectation was successful' if success?
  end
end
```

Additional helper functions are available when using the `spectre/assertion` module, 
which is loaded automatically by default.


### Assertion `spectre/assertion`

Make an assertion to any object by prepending one of the following functions

| Function | Description |
| -------- | ----------- |
| `should be` | Compares the objects value, with the given one and fails, if they are not equal. Values will be compared by their string value. |
| `should_not be` | Compares the two values like `should be`, but fails, if they are equal. |
| `should be empty` | Tests if a value is empty and fails if not. Fails, when a `list` has no elements or a `string` has no characters |
| `should_not be_empty` | Same as `should be_empty` but negated. |
| `should contain` | Tests if a given value is _in_ the other one. This can be a string containing another string, or a list containing a specific value. |
| `should_not contain` | Same like `should_contain` but negated. |
| `should match` | Matches the `string` against a given regular expression |
| `should_not match` | Same like `should_not_match` but negated. |

#### Examples

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    'Casper'.should be 'Casper' # does not fail
    'Casper'.should be 'Boogy' # fails
    'Casper'.should_not be 'Boogy' # does not fail

    [].should be empty # does not fail
    ''.should be empty # does not fail
    ['Casper', 'Boogy'].should be_empty # fails
    ['Casper', 'Boogy'].should_not be_empty # does not fail

    'Casper'.should contain 'spe' # does not fail
    'Casper'.should contain 'foo' # fails
    ['Casper', 'Boogy'].should contain 'Casper' # does not fail
    ['Casper', 'Boogy'].should contain 'Devy' # fails

    'Casper'.should match /^[a-z]+$/ # fails
    'Casper'.should_not match /Boogy/ # does not fail

    # etc. I think you got the concept
  end
end
```

Values can be combined with `or` and `and` in the following way

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'some assertions' do
      'Casper and Boogy are spooky'.should contain 'Casper'.or 'Boogy'
      'Casper and Boogy are spooky'.should contain 'Davy'.or ('Casper'.and 'Boogy')
      'Casper and Boogy are spooky'.should contain 'Davy'.or ('Casper'.and 'Boogy')
      'Casper and Boogy are spooky'.should_not contain 42.or 1337

      # etc. I think you got the concept
    end
  end
end
```


## Environments

Environment files provide a variable structure and module configuration, 
which can be accessed in any place of your *spec* definitions.
In the environment folder, create a plain yaml file with some variables.

`default.env.yml`

```yml
foo: bar
```

and access these variables with `env` in your *spec* files.

```ruby
describe 'Hollow API' do
  it 'reads values from environment' do
    expect 'foo to be bar' do
      env.foo.should be 'bar'
    end
  end
end
```

You can add more environment files and give them a name

`development.env.yml`

```yml
name: development
foo: bar
```

and use the environment by running `spectre` with the `-e NAME` parameter

```bash
$ spectre -e development
```

When no `-e` is given, the `default` environment is used. 
Any env yaml file without a specified `name` property, 
will be used as the default environment.

The environment file is merged with the `spectre.yml`, 
so you can override any property of your spectre config in each environment.
To show all variables of an environment, execute

```bash
$ spectre show
$ spectre show -e development
```

You can also override any of those variables with 
the command line parameter `-p` or `--property`

```bash
$ spectre -p foo=bla
$ spectre show -p foo=bla
```

By default all files in `environments/**/*.env.yml` will be read.
This can be changed by providing `env_patterns` in your `spectre.yml`

```yml
env_patterns:
  - environments/**/*.env.yml
  - ../common/environments/**/*.env.yml
  - ../*.environment.yml
```


#### Partial environment files

Environment files can be split into separate files. 
By default environment files with name `*.env.secret.yml` 
will be merged with the corresponding environment defined by the `name` property.

`environments/development.env.yml`

```yml
name: development
spooky_house:
  ghost: casper
  secret:
```

`environments/development.env.secret.yml`

```yml
name: development
spooky_house:
  secret: supersecret
```

These two files will result in the following config

```yml
name: development
spooky_house:
  ghost: casper
  secret: supersecret
```

With this approach you can check-in your common environment files into your 
Version Control and store secrets separately.

You can change the partial environment pattern, 
by adding the `env_partial_patterns` in your `spectre.yml`

```yml
env_partial_patterns:
  - environments/**/*.env.secret.yml
  - environments/**/*.env.partial.yml
```


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


## Running specs

In order to run our test, simply execute

```bash
$ spectre
```

The output should look something like this

```
Spooky
  always has the right answer
    starting to do some calculations ................................[info]
    expect the answer to be 42 ......................................[ok]
  does some strange things in the neighbourhood
    expect some ghost in the streets ................................[failed]
  only scares some people ...........................................[error]

1 failures 1 errors

  1) Spooky does some strange things in the neighbourhood [spooky-2]
       expected some ghost in the streets
       but it failed with:
       no ghosts

  2) Spooky only scares some people [spooky-3]
       but an error occurred while running the test
         file.....: specs/spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```

You can also run one or more specific specs

```bash
$ spectre -s spooky-1,spooky-3
```

```
Spooky
  always has the right answer
    starting to do some calculations.................................[info]
    expect the answer to be 42.......................................[ok]
  only scares some people............................................[error]

1 errors

  1) Spooky only scares some people [spooky-3]
       but an error occurred while running the test
         file.....: spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```

or run only specs with specific tags

```bash
$ spectre --tags scary+!dangerous,spooky
```

This will run all specs with the tags _scary_, but not _dangerous_, *or* with the tag _spooky_.

```
Spooky
  does some strange things in the neighbourhood
    expect some ghost in the streets.................................[failed]

1 failures 1 errors

  1) Spooky does some strange things in the neighbourhood [spooky-2]
       expect some ghost in the streets
       but it failed with no ghosts

  2) Spooky only scares some people [spooky-3]
       but an error occurred while running the test
         file.....: spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```


## Filtering specs

When listing or running specs, you might want to run only one or a specific set of specs. 
This can be done either by providing specific spec IDs, which can be listed by `spectre list`

```
$ spectre list
[spooky-1] Spooky always has the right answer #simple
[spooky-2] Spooky does some strange things in the neighbourhood #scary
[spooky-3] Spooky only scares some people #scary #dangerous
```

and passed with

```
$ spectre -s spooky-1,spooky-2
```

It is also possible to filter specs by tags

```
$ spectre -t scary,simple
```

This will run all specs with tag `scary` **or** `simple`.

```
$ spectre -t scary+dangerous
```

This will run all specs with tag `scary` **and** `dangerous`.

```
$ spectre -t scary+!dangerous
```

This will run all specs with tag `scary` and **not** `dangerous`.

```
$ spectre -t scary+!dangerous,simple
```

This will run all specs with tag `scary` and **not** `dangerous`, or with tag `simple`

If you want to run spec in a specific file, you can override the `spec_patterns` with

```
$ spectre --spec-pattern path/to/some.spec.rb
```


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
|   +-- staging.env.rb
|   +-- production.env.rb
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

## Modules

With the core framework you can run any tests you like, by writing plain Ruby code.
However, there are additional helper modules, you can use, to make your *specs* more readable.

All `spectre/*` modules are automatically loaded, if no modules 
are defined in the `spectre.yml` explicitly.


### Helpers `spectre/helpers`

There are some helper methods for various use cases

| Method | Data Types | Description |
| ------ | ---------- | ----------- |
| `as_json` | `string` | Parses the string as a `Hash` |
| `as_date` | `string` | Parses the string as a `DateTime` object |
| `content` | `string` | Treats the string as a file path and tries to read its content. Use `with` parameter to substitute placeholders in form of `#{foo}`. Example: `'path/to/file.txt'.content with:{foo: 'bar'}` |
| `with` | `string` | Substitute placeholders in form of `#{foo}` with the given `Hash`. Example: `'path/to/file.txt'.content with:{foo: 'bar'}` |
| `exist?` | `string` | Treats the string as a file path and returns `true` if the file exists, `false` otherwise |
| `remove!` | `string` | Treats the string as a file path and deletes the file |
| `size` | `string` | Treats the string as a file path and returns the file size |
| `trim` | `string` | Trims a long string to the given size. Default is 50 |
| `default_to!`, `defaults_to!` | `Hash`, `OpenStruct` | Sets default values to the `Hash` or `OpenStruct` |
| `to_json` | `OpenStruct` | Converts a `OpenStruct` object into a JSON string |
| `uuid(length=5)` | `Kernel` | Generates a UUID and returns characters with given length. Default is 5. |
| `pick` | `String`, `Hash`, `OpenStruct` | Applies a JsonPath to the data and returns the value. For more information about JsonPath see https://goessner.net/articles/JsonPath/ |
| `first_element` | _none_ | Returns the first element of a list. Was implemented to be consistent with `last_element` |
| `last_element` | _none_ | Returns the last element of a list. Was implemented, because some Ruby libraries override `Array.last`, which caused some issues. |


### Resources `spectre/resources`

The `resources` module reads all files in the default `resources` directory.

```
hollow_webapi
+-- environments
|   +-- development.env.rb
|   +-- staging.env.rb
|   +-- production.env.rb
+-- logs
+-- resources
|   +-- json
|       +-- spooky_request_body.json
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

The paths of these files are provided by the `resources` function. 
The files are accessed relative to the resources path.

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'the resource file to exist' do
      resources['json/spooky_request_body.json'].exist?.should be true
    end
  end
end
```

You can define the resources path in the `spectre.yml`

```yml
resource_paths:
- "../common/resources"
- "./resources"
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


### Diagnostic `spectre/diagnostic`

This module adds functions to track execution time.


```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    start_watch # start timer

    http 'dummy_api' do
      auth 'basic' # add this to use basic auth
      method 'GET'
      path 'employee/1'
    end

    stop_watch # stop timer

    # can also be used within the `measure` block
    measure do
      http 'dummy_api' do
        auth 'basic' # add this to use basic auth
        method 'GET'
        path 'employee/1'
      end
    end

    expect 'the duration to be lower than 1 sec'
      fail_with duration if duration > 1
    end
  end
end
```

`started_at` and `finished_at` are also available and return the according start or finish time.


### Reporter `spectre/reporter`

The following reporters are available with `spectre-core`

| Name | Module | Reference |
| ---- | ------ | --------- |
| Console | `spectre/reporters/console` | `Spectre::Reporter::Console` |

The reporter module provides some functions to add additional information to the report.

`property` lets you set a key-value pair which is included in the reports.
Use this to add generated values to the report.


```ruby
describe 'Hollow API' do
  it 'creates more ghosts' do
    ghost_name = create_random_ghost()

    property 'ghostname', ghost_name
  end
end
```


### Async `spectre/async`

You might want to execute some code in parallel or asynchronous within a test run.
To do so, wrap the code with `async` and `await` the result

```ruby
describe 'Hollow API' do
  it 'creates ghost' do
    async do
      http 'hollow' do
        path 'haunt'
      end

      response
    end

    result = await

    expect 'the the response code to be 200' do
      result.code.should be 200
    end
  end
end
```

You can also name your `async` calls

```ruby
describe 'Hollow API' do
  it 'creates ghost' do
    async 'haunt' do
      http 'hollow' do
        path 'haunt'
      end
    end

    async 'spooky' do
      http 'hollow' do
        path 'spooky'
      end
    end

    haunt_result = await 'haunt'
    spooky_result = await 'spooky'

    expect 'the response codes to be 200' do
      haunt_result.code.should be 200
      spooky_result.code.should be 200
    end
  end
end
```

When calling `async` multiple times with the same (or no) name, 
`await` will wait for all threads to finish with this name

```ruby
describe 'Hollow API' do
  it 'creates ghost' do
    async do
      'fist result'
    end

    async do
      'second result'
    end

    results = await

    expect 'multiple results' do
      results[0].should be 'fist result'
      results[1].should be 'second result'
    end

    async 'spooky' do
      'fist result'
    end

    async 'spooky' do
      'second result'
    end

    results = await 'spooky'

    expect 'multiple results' do
      results[0].should be 'fist result'
      results[1].should be 'second result'
    end
  end
end
```


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
        @@logger ||= defined?(Spectre.logger) ? Spectre.logger : Logger.new(STDOUT)
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
