# Spectre

> _You cross the line in this life, you choose the wrong side and you pay the price. All fees collected by -_ [The Spectre](https://dc.fandom.com/wiki/The_Phantom_Stranger_Vol_4_5)

Spectre is a DSL and tool set for test automation.

It is written in the scripting language [Ruby](https://www.ruby-lang.org/de/) and inspired by the Unit-Test framework [rspec](https://rspec.info/).


## Installation

To use the command line tool, Ruby has to be installed on your system. To install Ruby on Debian or Ubuntu run:

```bash
sudo apt-get install ruby-full
```

For other linux distributions see [ruby-lang.org](https://www.ruby-lang.org/en/documentation/installation/).

To install Ruby on windows, download an installer from [rubyinstaller.org](https://rubyinstaller.org/) or use a package manager like Chocolatey

```powershell
choco install ruby
```

The *spectre* gem is not yet available from an official gem repository. To install the tool, just clone this repository and execute `rake install`.
Note that `spectre` depends on the `ectoplasm` package. This package also is not yet available from an official gem repository. `rake install:full` will temporary clone the `ectoplasm` repository and install the gem automatically.

```bash
git clone https://cneubaur@bitbucket.org/cneubaur/spectre-ruby.git
cd spectre-ruby
sudo rake install # to install the spectre command line tool
sudo rake install:full # to install the spectre command line tool and the ectoplasm library

```

If in doubt use `sudo rake install:full`.

To test, if the tool is working, try one of the following commands.

```bash
spectre -h
spectre --version
```

### CURL

The `spectre/http` module requires `curl` to be installed on your system.

```bash
$ sudo apt install curl
```

Windows users can download `curl` from [https://curl.se/windows/](https://curl.se/windows/).
PowerShell has already a command named `curl`, which is an alias to `Invoke-WebRequest`
In order to use `curl` in the PowerShell, you have to remove the `curl` alias by executing

```powershell
PS C:\> rm alias:curl
```

and add the `bin` directory of the `curl` installation to your `PATH` environment variable.

```powershell
PS C:\> $env:Path += ";<path\to\curl\bin>"
```


### Troubleshoot

When getting an error message, like the one below, you have to install `bundler` first by running `sudo gem install bundler`.

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


### Postgres module

When using `spectre/database/postgres` module, the gem `pg` has to be installed manually.

```bash
sudo gem install pg
```

If installation fails, try install postgres postgres client first

```bash
sudo apt-get install postgresql-client libpq5 libpq-dev
sudo gem install pg
```


### MySQL module

In order to use the `spectre/mysql` module, you have to install the Ruby package `mysql2`.

On linux it is fairly easy. Just execute.

```bash
sudo apt-get install libmysqlclient-dev
sudo apt-get install mysql2
```

Yes, there is a reason why I mentioned the easy linux part. On Windows it is quite tricky... ok, not tricky, rather a pain... a pain in the a**.
A pain you should noone wish. A pain whereas even hell is a spa.

Want to go through this?

Ok, let's go. Try to install the package with `gem install mysql2` as it is intended.

```powershell
PS C:\> gem install mysql2
ERROR:  Error installing mysql2:
        The last version of mysql2 (>= 0) to support your Ruby & RubyGems was 0.5.3. Try installing it with `gem install mysql2 -v 0.5.3`
        mysql2 requires Ruby version >= 2.2, < 2.7.dev. The current ruby version is 2.7.0.0.
```

> Really? Do I have to downgrade my Ruby version?

No, fortunately not. Just get *Ruby 3.0*.

> But Ruby 3.0 is even greater?

Yes, I know. Don't ask too much. It works.

Ok, now we can install the package

```bash
gem install mysql2`
```

Haha, got you! You didn't thought it is that easy, right?! Right!

As windows does not have the MySQL client libraries installed, we have to add the argument `--without-mysql-dir`, when installing. For this, we need the libs first.
Ok, easy. You might think you go to the MySQL website and get the latest 64bit MySQL libraries as a ZIP file, extract it and pass the path to the argument, right? Wrong! Good and logical idea, but it won't work. Don't even try it (or try it, if you like it. I don't care).

Maybe you are smarter than me, know some C stuff and think "you are stupid, you need to use the 32bit version of the libs". Ok cool. Problem 1: There are no 32bit version of the latest MySQL libraries. Ok, let's get the next best version with 32bit libraries and try again.

Wohooo! It has been installed! Yeah! Let's get going and try it. Let's start `irb` and `require` the package.

```powershell
PS C:\> irb
irb(main):001:0> require 'mysql2'
Traceback (most recent call last):
       10: from C:/Tools/Ruby30-x64/bin/irb.cmd:31:in `<main>'
        9: from C:/Tools/Ruby30-x64/bin/irb.cmd:31:in `load'
        8: from C:/Tools/Ruby30-x64/lib/ruby/gems/3.0.0/gems/irb-1.3.0/exe/irb:11:in `<top (required)>'
        7: from (irb):1:in `<main>'
        6: from <internal:C:/Tools/Ruby30-x64/lib/ruby/3.0.0/rubygems/core_ext/kernel_require.rb>:149:in `require'
        5: from <internal:C:/Tools/Ruby30-x64/lib/ruby/3.0.0/rubygems/core_ext/kernel_require.rb>:160:in `rescue in require'
        4: from <internal:C:/Tools/Ruby30-x64/lib/ruby/3.0.0/rubygems/core_ext/kernel_require.rb>:160:in `require'
        3: from C:/Tools/Ruby30-x64/lib/ruby/gems/3.0.0/gems/mysql2-0.5.3/lib/mysql2.rb:36:in `<top (required)>'
        2: from <internal:C:/Tools/Ruby30-x64/lib/ruby/3.0.0/rubygems/core_ext/kernel_require.rb>:85:in `require'
        1: from <internal:C:/Tools/Ruby30-x64/lib/ruby/3.0.0/rubygems/core_ext/kernel_require.rb>:85:in `require'
RuntimeError (Incorrect MySQL client library version! This gem was compiled for 5.7.32 but the client library is 10.5.5.)
```

> You are kidding, right?

*Wrong!*. Really? You thought it would be *that* easy?!

"Ok, got it". Cool, but what's about this client library `10.5.5` version? Isn't MySQL only at `8.0.32` (it was at that point I wrote this)? Yes, it is, but who said we speak about MySQL? Ever heard from *MariaDB*, you dip sh**? Yes you got it, we need the MariaDB connector libs.

Go to https://mariadb.com/downloads/#connectors and download the latest one. Yes, *64bit* is fine. Install it and finally install the `mysql2` gem.

```bash
gem install mysql2 --platform=ruby -- '--with-mysql-dir="C:\Program Files\MariaDB\MariaDB Connector C 64-bit"'
```

Congratulations! You made it!


## Quickstart

To create a minimal spectre project run the following command

```bash
spectre init
```

This will create a basic folder structure and generate some sample files.


## Creating a new project

Create a new project structure by executing
```bash
spectre init
```

This will create mutliple empty directories and a `spectre.yaml` config file.

| Directory/File | Description |
| -------------- | ----------- |
| `environments` | This directory should contain `**/*_env.yaml` files. In these files, you can define environment variables, which can be accessed during a spec run. |
| `helpers` | This directory can contain any Ruby files. This path will be appended to Ruby's `$LOAD_PATH` variable. |
| `logs` | Logs will be placed in this folder |
| `reports` | This folder contains report files like JUnit, which are written by `reporter` |
| `resources` | This folder can contain any files, which will be used in *spec* definitions. |
| `specs` | This is the folder, where all spec files should be placed. The standard file pattern is `**/*_spec.rb` |
| `spectre.yaml` | This is `spectre`'s default config file. This file includes default file patterns and paths. Options in this file can be overritten with command line arguments. |
| `.gitignore` | This `.gitignore` file contains files and directories, which should not be tracked by version control. If created manually, make sure your environment files are not tracked. |


### Spectre Config

The following properties can be set in your `spectre.yml`

```yml
config_file: ./spectre.yml
environment: default
specs: empty
tags: empty
colored: yes
verbose: no
reporter: Spectre::Reporter::Console
logger: Spectre::Logger::Console
log_file: ./logs/spectre_<date>.log
out_path: ./reports
spec_patterns:
  - '**/*.spec.rb'
mixin_patterns:
  - '**/*.mixin.rb'
  - ../common/**/*.mixin.rb
env_patterns:
  - '**/*.env.yml'
env_partial_patterns:
  - '**/*.env.secret.yml'
resource_paths:
  - ../common/resources
  - ./resources
modules:
  - spectre/helpers
  - spectre/reporter/console
  - spectre/reporter/junit
  - spectre/logger/console
  - spectre/assertion
  - spectre/diagnostic
  - spectre/environment
  - spectre/mixin
  - spectre/bag
  - spectre/http
  - spectre/http/basic_auth
  - spectre/http/keystone
  - spectre/ssh
  - spectre/resources
  - ...
include:
  - spectre/mysql
exclude:
  - spectre/postgres
```

All properties can also be overriden with the command line argument `-p` or `--property`

```bash
spectre -p config_file=my_custom_spectre.yml -p environment=development
```


## Writing specs

To write automated tests, just open an editor of your choice and create a file named for example `spooky.spec.rb` in the `specs` folder.
Specs are structured in three levels. The *subject* defined by the keyword `describe`, the actual *spec* defined by the `it` keyword and one or more *expectation* described by the `expect` keyword. A *subject* can contain one or more *specs*.

Copy the following code into the file and save it

```ruby
def scare_people
  'Boo!'
end

describe 'Spooky' do
  it 'always has the right answer', tags: [:simple] do

    log 'starting to do some calculations'

    the_answer = 42

    expect 'the answer to be 42' do
      the_answer.should_be 42
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
      cry.should_be 'Boo!'
    end
  end

  context 'at midnight' do
    it 'only scares some people', tags: [:scary, :dangerous] do
      cry = scare_people()

      expect 'the cry to be scary' do
        cry.should_be 'Boo!'
      end
    end
  end
end
```


### Subject

A *subject* is the the top level description block of a testsuite. A *subject* can be anything, that groups functionality, e.g. some REST API, or an abstract business domain/process like *Order Process*.

A *subject* is described by the `describe` function, and can contain many `context`

```ruby
describe 'Hollow API' do
  # Add context here
end
```

> One *subject* can be split into multiple files. Note hat every `describe` call creates a new `context` and can contain its own `setup` and `teardown` blocks.


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

The *description* is optional. If omitted, all blocks in this context will be added to the main *context*. Blocks in the main context can also be defined in the *subject* directly.

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

> `setup`, `teardown`, `before` and `after` can be used multiple times within a context. These block will be executed in the provided order.


### Specification

*Specification* or *specs* define the actual tests and will be executed, when a test run is started. These blocks will be defined within a *context* block.

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

*Expectations* are defined within a *spec*. These blocks are description blocks like `describe`, `context` and `it`, but will be evaluated at runtime.

*Expectation* are fullfilled, when the code in this block runs without any errors. Unexpected runtime exceptions will generate an `error` status, will end the *spec* run and continue with the next *spec*.

Raising an `ExpectationFailure` exception in this block, will end up in a `failed` status and also end the *spec* run.


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

You don't have to raise an `ExpectationFailure` exception manually. In an `expect` block, there is the `fail_with <message>` function available. This function raises an `ExpectationFailure` with the given message.

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'some ghosts in the neighborhood' do
      fail_with 'no ghosts'
    end
  end
end
```

The status of an `expect` can be either `failed` or `error`. There are two more functions which end in only one of these, regardless of the `Exception` type. `check` will result always in `failed`, whereas `observe` will end always in an `error` status.

Additional helper functions are available when using the `spectre/assertion` module, which is loaded automatically.


### Assertion `spectre/assertion`

Make an assertion to any object by prepending one of the following functions

| Function | Description |
| -------- | ----------- |
| `should_be` | Compares the objects value, with the given one and fails, if they are not equal. Values will be compared by their string value. |
| `should_not_be` | Compares the two values like `should_be`, but fails, if they are equal. |
| `should_be_empty` | Tests if a value is empty and fails if not. Fails, when a `list` has no elements or a `string` has no characters |
| `should_not_be_empty` | Same as `should_be_empty` but negated. |
| `should_contain` | Tests if a given value is _in_ the other one. This can be a string containing another string, or a list containing a specific value. |
| `should_not_contain` | Same like `should_contain` but negated. |
| `should_match` | Matches the `string` against a given regular expression |
| `should_not_match` | Same like `should_not_match` but negated. |

#### Examples

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'some assertions' do
      'Casper'.should_be 'Casper' # does not fail
      'Casper'.should_be 'Boogy' # fails
      'Casper'.should_not_be 'Boogy' # does not fail

      [].should_be_empty # does not fail
      ''.should_be_empty # does not fail
      ['Casper', 'Boogy'].should_be_empty # fails
      ['Casper', 'Boogy'].should_not_be_empty # does not fail

      'Casper'.should_contain 'spe' # does not fail
      'Casper'.should_contain 'foo' # fails
      ['Casper', 'Boogy'].should_contain 'Casper' # does not fail
      ['Casper', 'Boogy'].should_contain 'Devy' # fails

      'Casper'.should_match /^[a-z]+$/ # fails
      'Casper'.should_not_match /Boogy/ # does not fail

      # etc. I think you got the concept
    end
  end
end
```


## Environments

Environment files provide a variable structure and module configuration, which can be accessed in any place of you spec definitions.
In the environment folder, create a plain yaml file with some variables.

`default.env.yml`

```yml
foo: bar
```

and access these variables with `env` in you spec files.

```ruby
describe 'Hollow API' do
  it 'reads values from environment' do
    expect 'foo to be bar' do
      env.foo.should_be 'bar'
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

and use the environment by running spectre with the `-e NAME` parameter

```bash
spectre -e development
```

When no `-e` is given, the `default` environment is used. Any env yaml file without a specified `name` property, will be used as the default environment.

The environment file is merged with the `spectre.yml`, so you can override any property of you spectre config in each environment.
To show all variables of an environment, execute

```bash
spectre show
spectre show -e development
```

You can also override any of those variables with the command line parameter `-p` or `--property`

```bash
spectre -p foo=bla
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

Environment files can be split into sperarate files. By default environment files with name `*.env.secret.yml` will be merged
with the corrensponding environment defined by the name property.

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

With this approach you can check in your common environment files into your Version Control and store secrets separately.

You can change the partial environment pattern, by adding the `env_partial_patterns` in you `spectre.yml`

```yml
env_partial_patterns:
  - environments/**/*.env.secret.yml
  - environments/**/*.env.partial.yml
```


## Listing specs

To list specs execute

```bash
spectre list
```

The output looks like this

```
[spooky-1] Spooky always has the right answer #simple
[spooky-2] Spooky does some strange things in the neighbourhood #scary
[spooky-3] Spooky only scares some people #scary #dangerous
```

The name in the brackets is an identifier for a spec. This can be used to run only specific specs.
Note that this ID can change, when more specs are added.

## Running specs

In order to run our test, simply execute

```bash
spectre
```

The output should look like this

```
Spooky
  always has the right answer
    starting to do some calculations ................................[info]
    expect the answer to be 42 ......................................[ok]
  does some strange things in the neighbourhood
    expect some ghost in the streets ................................[failed - 1]
  only scares some people ...........................................[error - 2]

1 failures 1 errors

  1) Spooky does some strange things in the neighbourhood [spooky-2]
       expected some ghost in the streets
       but it failed with no ghosts

  2) Spooky only scares some people [spooky-3]
       but an error occured while running the test
         file.....: specs/spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```

You can also run one or more specific specs

```bash
spectre -s spooky-1,spooky-3
```

```
Spooky
  always has the right answer
    starting to do some calculations.................................[info]
    expect the answer to be 42.......................................[ok]
  only scares some people............................................[error - 2]

1 errors

  1) Spooky only scares some people [spooky-3]
       but an error occured while running the test
         file.....: spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```

or run only specs with specific tags

```bash
spectre --tags scary+!dangerous,spooky
```

This will run all specs with the tags _scary_, but not _dangerous_, or with the tag _spooky_.

```
Spooky
  does some strange things in the neighbourhood
    expect some ghost in the streets.................................[failed - 1]

1 failures 1 errors

  1) Spooky does some strange things in the neighbourhood [spooky-2]
       expect some ghost in the streets
       but it failed with no ghosts

  2) Spooky only scares some people [spooky-3]
       but an error occured while running the test
         file.....: spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```


## Advanced writing specs

Your project could consist of hundreds and thousand of specs. In order to easier maintain your project, it is recommended to place *specs* of a *subject* in different `*.spec.rb` files and folders, grouped by a specific context. A *subject* can be described in multiple files.

For example, when writing *specs* for a REST API, the *specs* could be grouped by the APIs *resources* in different folders, and their *operations* in different files.

Specs of a RPC API can be grouped by its functions.

Our *Hollow API* has two resources *ghosts* and *monsters*. Each resource can be *created*, *read*, *updated* and *deleted*. The project structur could then look something like this:

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
However, there are additional helper modules, you can use, to make you Specs more readable.

All `spectre/*` modules are automatically loaded, if no modules are defined in the `spectre.yml` explicitly.


### HTTP `spectre/http`

HTTP requests can be invoked like follows

```ruby
http 'dummy.restapiexample.com/api/v1/' do
  method 'GET'
  path 'employee/1'
  param 'foo', 'bar'
  param 'bla', 'blubb'
  header 'X-Authentication', '*****'
  header 'X-Correlation-Id', ''
  json({
    "message": "Hello Spectre!"
  })
  content_type 'plain/text'
  body 'Some plain text body content'
end
```

You can also use `https` to enable SSL requests.

```ruby
https 'dummy.restapiexample.com/api/v1/' do
  method 'GET'
  path 'employee/1'
end
```

The parameter can either be a valid URL or a name of the config section in your environment file under `http`.

Example:

```yaml
http:
  dummy_api:
    base_url: http://dummy.restapiexample.com/api/v1/
```

In order to do requests with this HTTP client, use the `http` or `https` helper function.

```ruby
http 'dummy_api' do
  method 'GET'
  path 'employee/1'
end
```

When using `https` it will override the protocol specified in the config.

You can set the following properties in the `http` block:

| Method | Arguments | Multiple | Description |
| -------| ----------| -------- | ----------- |
| `method` | `string` | no | The HTTP request method to use. Usually one of `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD` |
| `param` | `string`,`string` | yes | Adds a query parameter to the request |
| `json` | `Hash` | no | Adds the given hash as json and sets content type to `application/json` |
| `header` | `string`,`string` | yes | Adds a header to the request |
| `content_type` | `string` | no | Sets the `Content-Type` header to the given value |


Access the response with the `response` function. This is an object with the following properties:

| Method | Description |
| -------| ----------- |
| `code` | The response code of the HTTP request |
| `message` | The status message of the HTTP response, e.g. `Ok` or `Bad Request` |
| `body` | The plain response body as a string |
| `json` | The response body as JSON data of type `OpenStruct` |
| `headers` | The response headers as a dictionary. Header values can be accessed with `res.headers['Server']`. The header key is case-insensitive. |

```ruby
response.code.should_be 200
response.headers['server'].should_be 'nginx'
```

#### Basic Auth `spectre/http/basic_auth`

Adds `basic_auth` to the HTTP module.

```ruby
http 'dummy_api' do
  basic_auth 'someuser', 'somepassword'
  method 'GET'
  path 'employee/1'
end
```

You can also add basic auth config parameters to your `spectre.yml` or environment files.

```yaml
http:
  dummy_api:
    base_url: http://dummy.restapiexample.com/api/v1/
    basic_auth:
      username: 'dummy'
      password: 'someawesomepass'
```

And tell the client to use basic auth.

```ruby
http 'dummy_api' do
  auth 'basic_auth' # add this to use basic auth
  method 'GET'
  path 'employee/1'
end
```

#### Basic Auth `spectre/http/keystone`

Adds keystone authentication to the HTTP client.

Add keystone authentication properties to the http client in you `spectre.yml`

```yaml
http:
  dummy_api:
    base_url: http://dummy.restapiexample.com/api/v1/
    keystone:
      url: https://some-keystone-server:5000/main/v3/
      username: dummy
      password: someawesomepass
      project: some_project
      domain: some_domain
      cert: path/to/cert
```

And tell the client to use keystone authentication.

```ruby
http 'dummy_api' do
  auth 'keystone' # add this to use keystone
  method 'GET'
  path 'employee/1'
end
```

You can also use the keystone method, to use keystone authentication directly from the `http` block

```ruby
http 'dummy_api' do
  method 'GET'
  path 'employee/1'
  keystone 'https://some-keystone-server:5000/main/v3/', 'dummy', 'someawesomepass', 'some_project', 'some_domain', 'path/to/cert'
end
```


### SSH `spectre/ssh`

With the SSH helper you can define SSH connection parameter in the environment file and use the `ssh` function in your specs.

Example:

```yaml
ssh:
  some_ssh_conn: # name of the connection
    host: some.server.com
    username: u123456
    password: $up3rSecr37
```

within the `ssh` block there are the following functions available

| Method | Parameters | Description |
| -------| ---------- | ----------- |
| `file_exists` | `file_path` | Checks if a file exists and return a boolean value |
| `owner_of` | `file_path` | Returns the owner of a given file |
| `can_connect?` | _none_ | Returns `true` if a connection could be established |


```ruby
ssh 'some_ssh_conn' do # use connection name from config
  file_exists('../path/to/some/existing_file.txt').should_be true
  owner_of('/bin').should_be 'root'
end
```

You can also use the `ssh` function without configuring any connection in you environment file, by providing parameters to the function.
This is helpful, when generating the connection parameters during the spec run.
The name of the connection is then only used for logging purposes.

```ruby
ssh 'some_ssh_conn', host: 'some.server.com', username: 'u123456', password: '$up3rSecr37'  do
  file_exists('../path/to/some/existing_file.txt').should_be true
  owner_of('/bin').should_be 'root'
end
```


### FTP `spectre/ftp`

With the FTP helper you can define FTP connection parameter in the environment file and use either `ftp` or `sftp` function in your specs.

Example:

```yaml
ftp:
  some_ftp_conn: # name of the connection
    host: some.server.com
    username: u123456
    password: $up3rSecr37
```

within the `ftp` or `sftp` block there are the following functions available

| Method | Parameters | Description |
| -------| ---------- | ----------- |
| `upload` | `local_file`, `to: remote_file` | Uploads a file to the given destination |
| `download` | `remote_file`, `to: local_file` | Downloads a file from the server to disk |
| `can_connect?` | _none_ | Returns `true` if a connection could be established |


```ruby
sftp 'some_ftp_conn' do # use connection name from config
  upload 'dummy.txt' # uploads file to the root dir of the FTP connection
  download 'dummy.txt' # downloads file to the current working directory\
  download 'dummy.txt', to: '/tmp/dummy.txt' # downloads file to the given destination
end
```

You can also use the `ftp` and `sftp` function without configuring any connection in you environment file, by providing parameters to the function.
This is helpful, when generating the connection parameters during the spec run.
The name of the connection is then only used for logging purposes.

```ruby
sftp 'some_ftp_conn', host: 'some.server.com', username: 'u123456', password: '$up3rSecr37' do # use connection name from config
  upload 'dummy.txt' # uploads file to the root dir of the FTP connection
  download 'dummy.txt' # downloads file to the current working directory\
  download 'dummy.txt', to: '/tmp/dummy.txt' # downloads file to the given destination
end
```


### MySQL `spectre/mysql`

Adds an easy way to execute SQL queries on a MySQL database.

You can set the following properties in the `mysql` block:

| Method | Arguments | Multiple | Description |
| -------| ----------| -------- | ----------- |
| `host` | `string` | no | The hostname of the database to connec to |
| `database` | `string` | no | The database to use, when executing queries |
| `username` | `string` | no | The username to authenticate at the database |
| `password` | `string` | no | The passwort for authentication |
| `query` | `string` | yes | The queries which will be executed. Note that only the last query generates a `result` |

The result of the query can be accessed by the `result` function. It contains all rows returned by the database.

When a name is provided to `mysql`, it uses either a preconfigured connection with this name or uses the name as the database hostname.

Example:

```ruby
mysql 'localhost' do
  database 'developer'
  username 'root'
  password 'dev'

  query "INSERT INTO todos VALUES('Spook arround', false)"
  query "INSERT INTO todos VALUES('Scare some people', false)"
  query "SELECT * FROM todos"
end

expect 'two entries in database' do
  result.count.should_be 2
end

expect 'the first todo not to be completed' do
  result.first.done.should_be false
end
```

You can also preconfigure a MySQL connection in your environment file.

```yml
mysql:
  developer:
    host: localhost
    database: developer
    username:
    password:
```

and use the connection by providing the section name to the `mysql` call.

```ruby
mysql 'developer' do
  query "INSERT INTO todos VALUES('Spook arround', false)"
  query "INSERT INTO todos VALUES('Scare some people', false)"
  query "SELECT * FROM todos"
end
```

If you want to execute additional queries with the same connection as on the previous `mysql` block, you can simply ommit the `name` parameter.

```ruby
mysql do
  query "INSERT INTO todos VALUES('Rattle the chains', false)"
end
```


### Environment `spectre/environment`

Add arbitrary properties to your `spectre.yml`

```yml
spooky_house:
  ghost: casper
```

and get the property via `env` function.

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'the environment variable to exist' do
      env.spooky_house.ghost.should_be 'casper'
    end
  end
end
```


### Helpers `spectre/helpers`

There are some helper methods for various use cases

| Method | Data Type | Description |
| -------| ----------| -------- | ----------- |
| `as_json` | `string` | Parses the string as a `Hash` |
| `as_date` | `string` | Parses the string as a `DateTime` object |
| `content` | `string` | Treats the string as a file path and tries to read its content. Use `with` parameter to substitute placeholders in form of `#{foo}`. Example: `'path/to/file.txt'.content with:{foo: 'bar'}` |
| `exists?` | `string` | Treats the string as a file path and returns `true` if the file exists, `false` otherwise |
| `remove!` | `string` | Treats the string as a file path and deletes the file |
| `to_json` | `OpenStruct` | Converts a `OpenStruct` object into a JSON string |
| `uuid(length=5)` | `Kernel` | Generates a UUID and returns characters with given length. Default is 5. |



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

The paths of these files are provided by the `resources` function. The files are accessed relative to the resources path.

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    expect 'the resource file to exist' do
      resources['json/spooky_request_body.json'].exists?.should_be true
    end
  end
end
```


### Mixins `spectre/mixin`

You can define reusable specs by using mixins. Create a `.mixin.rb` file in the mixin directory (default: `mixins`)

```ruby
mixin 'check health' do |http_name| # the mixin can be parameterized
  http http_name do
    auth 'basic'
    method 'GET'
    path 'health'
  end

  expect 'the response code to be 200' do
    response.code.should_be 200
  end

  expect 'the status to be ok' do
    response.json.status.should_be 'Ok'
  end

  expect 'the alarm to be ok' do
    response.json.status.should_be 'Ok'
  end
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

Like every ruby block or function, a mixin has also a return value (the last expression in the `do` block)

```ruby
mixin 'do some spooky stuff' do
  # spook around

  'Boo!'
end
```

This can be used like that:

```ruby
describe 'Hollow API' do
  it 'is scary' do
    result = run 'do some spooky stuff'

    expect 'some spooky things' do
      result.should_be 'Boo!'
    end
  end
end
```

### Diagnostic `spectre/diagnostic`

This module adds function to track execution time.


```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    start # start timer

    http 'dummy_api' do
      auth 'basic' # add this to use basic auth
      method 'GET'
      path 'employee/1'
    end

    stop # stop timer

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

## Release Notes

### v1.6.0

#### Major
 - `curl` module added to perform HTTP requests. This requires `curl` to be installed. Windows users can download `curl` [https://curl.se/windows/](https://curl.se/windows/). Either add the `bin` dir to you `PATH` environment variable, or set `curl_path` in your `spectre.yml` to the path where`curl.exe` is located.
 - Logging optimized
    - It is now possible to use `log` and `debug` functions in any block in your code
    - Setup, teardown, before and after blocks are now logged like context, to distinguish from the actual spec logs.
    - Logger are refactored. It is now possible to configure multiple loggers at once. The property in the `logger` (in `spectre.yml`) is replaced with `loggers` and is now a list of logging modules
    - `log_level` was removed from `spectre.yml` and is replaced with `debug` which can be `true` or `false` (default: `false`)
 - MySQL module added. See `spectre/mysql` for more details
 - Error handling in `setup` and `teardown` blocks optimized. Expectation failures in `setup` and `teardown` blocks are now reported. Additionally, if an expectation in a `setup` block fails, the test run will be aborted. This allows prechecks for each context to run.
 - `check` function added. The `check` function behaves just like the `expect` function, except that it will always result in a *failure* regardless of the exception caused the failure. In other words, this block only produces `failures` and no `errors`.
 - `observe` function added. The `observe` function is like the `check` function, but it always results in an `error` instead of an `failure`.

#### Minor
 - `secure` parameter added for `http` module. You can now use `https` by calling `http url, secure: true do`
 - The `path` parameter for the `http` block is now optional
 - The `ssh` and `ftp` module have new a new function `can_connect?` to test connection
 - Include and exclude of modules added. You can now add modules to the default list by adding the `include` property in your `spectre.yml`. You can also exclude modules (which are normally loaded on default) by adding a list of modules to the `exclude` property.


### v1.5.0

#### Major
 - HTTP module refactored. See _HTTP_ section above.

#### Minor
 - Partial environment files added. See _Environment_ section above.
 - Debug logging added. use `debug 'some info text'` to create debug log entries in files and console output
 - `log_level` config property added. When set to `DEBUG`, additional `spectre` log will be written.
 - Duplicate environment definition check added. When there are more than one environments defined with the same name in different files, spectre will not continue executing.
 - Method delegation fixed. For example, it is now possible to use `response` within other `http` blocks for refering to a previous HTTP response.
 - Mixins can now be executed with `run`, `step` or `also`
 - Small bugfixes