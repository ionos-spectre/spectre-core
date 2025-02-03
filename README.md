<div align="center">
  <img src="./spectre_icon.png?raw=true" alt="IONOS Spectre" style="width:200px">
  <h2>IONOS Spectre</h2>
  <p>Describe Tests. Analyse Results. Understand What Happened.</p>
  <a href="https://github.com/ionos-spectre/spectre-core/actions/workflows/build.yml"><img src="https://github.com/ionos-spectre/spectre-core/actions/workflows/build.yml/badge.svg" alt="Build Status" /></a>
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
| :----- | :------------ |
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

Ruby has to be installed on your system. 

See [ruby-lang.org](https://www.ruby-lang.org/en/documentation/installation/) for installation instructions.

To install Ruby on windows, just use `winget`

```powershell
# Search for available Ruby versions
winget search ruby

# Install Ruby with dev kit
winget instal RubyInstallerTeam.RubyWithDevKit.3.4
```

Spectre is available as a Ruby *gem* from the GitHub packages 
repository https://rubygems.pkg.github.com/ionos-spectre

It is recommended to create a `Gemfile` and install `spectre-core` with bundler.

```ruby
source "https://rubygems.pkg.github.com/ionos-spectre" do
  gem "spectre-core", "1.14.6"
end
```

```bash
$ bundle install
```

You can also install the tool globally with

```bash
$ gem install spectre-core
```

or clone this repository and run

```bash
rake install
```

To test, if the tool is working, try one of the following commands.

```bash
# When using bundler
$ bundle exec spectre -h

# otherwise
$ spectre -h
```


## Creating a new project

Create a new project structure by executing

```bash
$ spectre init
```

This will create multiple empty directories and a `spectre.yml` config file.

| Directory/File | Description |
| :------------- | :---------- |
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

See [Spectre::CONFIG](./lib/spectre.rb#L702-L723) for default values and available options.

All options can also be overridden with the command line argument `-p` or `--property`

```bash
$ spectre -p config_file=my_custom_spectre.yml -p "log_file=/var/log/spectre/spectre-<date>.log"
```

You can also create a global spectre config file with the options above. 
Create a `spectre.yml` file in your users `.config` directory (`~/config/spectre.yml`) 
and set the options which shall be used for all projects on your computer.


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
    also 'check health', with: ['hollow_api'] # pass mixin parameter as value list
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
