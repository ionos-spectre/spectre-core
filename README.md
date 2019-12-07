# Spectre

> _You cross the line in this life, you choose the wrong side and you pay the price. All fees collected by -_ [The Spectre](https://dc.fandom.com/wiki/The_Phantom_Stranger_Vol_4_5)

Spectre is a DSL to describe blackbox tests and a command line tool to run these specifications.

It is written in the scripting language [Ruby](https://www.ruby-lang.org/de/) and based on the Unit-Test framework [rspec](https://rspec.info/).

## Installation

To use the command line tool, Ruby hast to be installed on your system. To install Ruby on Debian or Ubuntu run:

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
| `.gitignore` | This `.gitignore` file contains files and directories, which should not be tracked by version control. |

## Writing specs

To write tests, just open an editor of your choice and create a file named for example `spooky_spec.rb` in the `specs` folder.
Specs are structured in three levels. The *subject* defined by the keyword `describe`, the actual *spec* defined by the `it` keyword and one or more *expectiation* described by the `expect` keyword. A *subject* can contain one or more *specs*.

Copy the following code into the file and save it

```ruby
def do_some_spooky_things
  true
end

describe 'Spooky' do
  it 'should always have the right answer', tags: [:simple] do

    log 'starting to do some calculations'

    the_answer = 42

    expect 'the answer to be 42' do
      fail if the_answer.is_not 42
    end
  end

  it 'should do some strange things in the neighbourhood', tags: [:scary] do
    expect 'some ghosts in the streets' do
      fail with: 'no ghosts'
    end
  end

  it 'should only scare some people', tags: [:scary, :dangerous] do
    people_screamed = do_some_spooky_things()

    raise 'town was destroyed instead'

    expect 'the people to scream' do
      fail if !people_screamed
    end
  end
end
```

## Listing specs

To list specs execute

```bash
spectre list
```

The output looks like this

```
[spooky-1] Spooky should always have the right answer #simple
[spooky-2] Spooky should do some strange things in the neighbourhood #scary
[spooky-3] Spooky should only scare some people #scary #dangerous
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
  should always have the right answer
    starting to do some calculations...................................................[info]
    expect the answer to be 42.........................................................[ok]
  should do some strange things in the neighbourhood
    expect some ghost in the streets...................................................[failed - 1]
  should only scare some people........................................................[error - 2] RuntimeError

1 failures 1 errors

  1) Spooky should do some strange things in the neighbourhood [spooky-2]
       expect some ghost in the streets
       but it failed with no ghosts

  2) Spooky should only scare some people [spooky-3]
       but an error occured while running the test
         file.....: spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```

To output your `log` messages and get a more detailed report, execute

```
spectre -v
```

You can also run one or more specific specs

```bash
spectre -s spooky-1,spooky-3
```

```
Spooky
  should always have the right answer
    starting to do some calculations...................................................[info]
    expect the answer to be 42.........................................................[ok]
  should only scare some people........................................................[error - 2] RuntimeError

1 failures 1 errors

  1) Spooky should only scare some people [spooky-3]
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
  should do some strange things in the neighbourhood
    expect some ghost in the streets...................................................[failed - 1]
  should only scare some people........................................................[error - 2] RuntimeError

1 failures 1 errors

  1) Spooky should do some strange things in the neighbourhood [spooky-2]
       expect some ghost in the streets
       but it failed with no ghosts

  2) Spooky should only scare some people [spooky-3]
       but an error occured while running the test
         file.....: spooky_spec.rb
         line.....: 18
         type.....: RuntimeError
         message..: town was destroyed instead
```


## Advanced writing specs

Your project could consist of hundreds and thousand of specs. In order to easier maintain your project, it is recommended to place *specs* of a *subject* in different `*_spec.rb` files and folders, grouped by a specific context. A *subject* can be described in multiple files.

For example, when writing *specs* for a REST API, the *specs* could be grouped by the APIs *resources* in different folders, and their *operations* in different files.

Our *Awesome API* has two resources *ghosts* and *monsters*. Each resource can be *created*, *updated* and *deleted*. The project structur could then look something like this:

```
awesome_api
+-- configs
|   +-- default_config.rb
+-- enironments
|   +-- development_env.rb
|   +-- staging_env.rb
|   +-- production_env.rb
+-- helpers
|   +-- awesome_api_client.rb
+-- logs
+-- mixins
+-- resources
|   +-- ca_file.cer
+-- specs
|   +-- ghosts <-- first resource
|   |   +-- create_spec.rb
|   |   +-- update_spec.rb
|   |   +-- delete_spec.rb
|   |   +-- spook_spec.rb
|   +-- monsters <-- second resource
|       +-- create_spec.rb
|       +-- update_spec.rb
|       +-- delete_spec.rb
+-- spectre.yaml
```

## Helpers

### HTTP

A common usecase for *spectre* is to write black box tests for a REST API.
A HTTP API can be easily accessed with spectre's HTTP client. To create a HTTP client simply use the `http` wrapper.

```ruby
AWESOME_API = http('awesome-api.com/api/v1')
```

Configure the HTTP client by chaining the following method calls.

| Method | Arguments | Description |
| ------ | --------- | ----------- |
| `ssl` | *none* | Enable SSL communication |
| `cert` | `ca_file`   | Add a ca file to validate communication. This sets `ssl` automatically |
| `basic_auth` | `username`, `password` | Add basic auth authentication to requests |
| `keystone` | `token` | Add a keystone token to requests for authentication. This adds a request header `X-Auth-Token` with the given token as the value, to every request |
| `log` | `file` | Tell the HTTP client to log to the given file |

Full example:

```ruby
AWESOME_API = http('awesome-api.com/api/v1')
  .cert('path/to/ca_file.cer')
  .log('./logs/request.log')
  .basic_auth('admin', '#Sup3r$ecre7P4s$')
```

Create a request by providing a URL path in squared brackets like

```ruby
request = AWESOME_API['ghosts/casper/skills']
```

Modify requests by chaining the following methods

| Method | Arguments | Description |
| ------ | --------- | ----------- |
| `params` | `query` | Add query params to the URL. The parameters are given as a `Hash`. |
| `headers` | `headers` | Add additional request headers |
| `data` | `data` | Add request data as JSON |

Finally execute the request with either `get`, `post`, `delete`, `patch`, `put`. This will return a standard Ruby  `HTTPResponse`.

The following methods are additionally available for a response.

| Method | Arguments | Description |
| ------ | --------- | ----------- |
| `ensure` | `code` | Raise an error, if the response does not have the given status code |
| `data` | *none* | Get the response data as a `Hash` |

Full example:

```ruby
# Create a HTTP client
AWESOME_API = http('awesome-api.com/api/v1')
  .cert('path/to/ca_file.cer')
  .log('./logs/request.log')
  .keystone('<some_keystone_token>')

# Get a resource
skills = AWESOME_API['ghosts/casper/skills']
  .get
  .ensure(200)
  .data

# Create a new resource
new_skill = AWESOME_API['ghosts/casper/skills']
  .data({
    name: 'spook',
    energy: 42,
  })
  .post
  .ensure(201)
  .data
```

### SSH

As easy as the HTTP client is, so is the SSH client. Simply create a client by using the `ssh` wrapper function and provide a `host` with a `user`.

```ruby
ssh_conn = ssh('casper@192.168.0.42')
```

The following methods can be chained to add connection parameters.

| Method | Arguments | Description |
| ------ | --------- | ----------- |
| `key` | `file_path` | Use the SSH key at the given path for connection to the host |
| `passphrase` | `passphrase` | The passphrase for the given key |
| `password` | `password` | Use a password to authenticate the SSH connection |
| `log` | `file_path` | Log output to the given path |

Execute a command by executing:

```ruby
ssh_conn = ssh('casper@192.168.0.42')

result, error = ssh_conn.exec 'ls -al'
```

The output of the command is provided as a string in the `result`. If an error occured (output in `stderr`), it is provided in the `error`.