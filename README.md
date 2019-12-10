# Spectre

> _You cross the line in this life, you choose the wrong side and you pay the price. All fees collected by -_ [The Spectre](https://dc.fandom.com/wiki/The_Phantom_Stranger_Vol_4_5)

Spectre is a DSL to describe any kind of tests and a command line tool to run these specifications.

It is written in the scripting language [Ruby](https://www.ruby-lang.org/de/) and based on the Unit-Test framework [rspec](https://rspec.info/).

This DSL is not only helpful for writing tests, it can also be used to describe a subject (e.g. a REST API) and provide readable examples of usage for on technical documentation.

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

The *spectre* gem is not yet available from an official gem repository. To install the tool, just clone this repository and execute

```bash
bundle install # to install gem dependencies
sudo rake install # to install the command line tool
```

To test, if the tool is working, try one of the following commands.

```bash
spectre -h
spectre --version
```

## Creating a new project

<!-- 
Create a new project structure by executing
```bash
spectre init
```

This will create mutliple empty directories and a `spectre.yaml` config file.

| Directory/File | Description |
| -------------- | ----------- |
| `configs` | This directory should include `**/*_conf.rb` files. These configs will be executed once, before running any `spec` files. |
| `environments` | This directory should contain `**/*_env.yaml` files. In these files, you can define environment variables, which can be accessed during a spec run. |
| `helpers` | This directory can contain any Ruby files. This path will be appended to Ruby's `$LOAD_PATH` variable. |
| `logs` | Logs will be placed in this folder |
| `mixins` | This folder should include mixin definition files `**/*_mixin.rb` |
| `resources` | This folder can contain any files, which will be used in *spec* definitions. |
| `specs` | This is the folder, where all spec files should be placed. The standard file pattern is `**/*_spec.rb` |
| `spectre.yaml` | This is `spectre`'s default config file. This file includes default file patterns and paths. Options in this file can be overritten with command line arguments. |
| `.gitignore` | This `.gitignore` file contains files and directories, which should not be tracked by version control. | -->

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

  it 'does some strange things in the neighbourhood', tags: [:scary] do
    expect 'some ghosts in the streets' do
      fail_with 'no ghosts'
    end
  end

  it 'only scares some people', tags: [:scary, :dangerous] do
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

A *subject* is the the top level description of a testsuite. A *subject* can be anything, that groups functionality, e.g. some REST API, or a business domain/process like *Order Process*.

A *subject* is described by the `describe` function, and can contain many `context`

```ruby
describe 'Hollow API' do
  # Add context here
end
```

> One *subject* can be split into multiple files.


### Context

A *context* groups one or more *specifications* and can add an additional description layer.
The description is optional. Within a *context*, there are 4 additional function available.

A *context* can be create with `context <description> do [...] end`

| `setup` | Runs once at the **beginning** of the *context*. It can be used to create some specific state for tests in this context. |
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

*Specification* or *specs* define the actual tests and will be executed, when a test run is started. These blocks will be defined within a *context* block. Use `it <description> do [...] end` to define a *spec* block.

```ruby
describe 'Hollow API' do
  it 'sends out spooky ghosts' do
    # Do some API calls or what ever here
  end

  context 'at midnight' do
    it 'sends out spooky ghosts' do
      # Do some API calls or whatever
    end
  end
end
```

*spec* blocks contain Ruby code and one or multiple *expectations*.


### Expectation

*Expectations* are defined within a *spec*. These blocks are descriptions blocks like `describe`, `context` and `it`, but will be evaluated at runtime.

*Expectation* are fullfilled, when the code in this block runs without any errors. Unexpected runtime exceptions will generate an `error` status, will end the *spec* run and and continue with the next *spec*.

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

Additional helper function are available when using the `spectre/assertion` module, which is loaded automatically, when not deactivated explicitly.


### Assertion




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

1 failures 1 errors

  1) Spooky only scares some people [spooky-3]
       but an error occured while running the test
         file.....: spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```

or run only specs with specific tags

```bash
spectre --tags scary
```

```
Spooky
  does some strange things in the neighbourhood
    expect some ghost in the streets.................................[failed - 1]
  only scares some people............................................[error - 2]

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

Our *Hollow API* has two resources *ghosts* and *monsters*. Each resource can be *created*, *updated* and *deleted*. The project structur could then look something like this:

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
|   |   +-- update.spec.rb
|   |   +-- delete.spec.rb
|   |   +-- spook.spec.rb
|   +-- monsters
|       +-- create.spec.rb
|       +-- update.spec.rb
|       +-- delete.spec.rb
+-- spectre.yaml
```

## Helpers

With the core framework you can run any tests you like, by writing plain Ruby code.
However, there are additional helper modules, you can use, to make you Specs more readable.

### HTTP

Configure a HTTP client in the environment files at the `http` section.

Example:

```yaml
http:
  dummy_api:
    base_url: http://dummy.restapiexample.com/api/v1/
```

In order to do requests with this HTTP client, use the `http` helper function.

```ruby
http 'dummy_api' do
  method 'GET'
  path 'employee/1'
  param 'foo', 'bar'
  header 'X-Authentication', '*****'
end
```

Access the response with with the `response` function. This function returns a standard `Net::HTTPResponse` object with additional extension methods available.

```ruby
response.code.should_be 200
```

| Method | Description |
| -------| ----------- |
| `json` | Parses the response body as JSON data and returns a `OpenStruct` instance |