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

Spectre core only contains logic to run, log and report tests. For more functionality like
HTTP requests, SSH command, database access,... see [ionos-spectre](https://github.com/ionos-spectre).

See [minimal example module](example/modules/phone.rb) for a minimal module example and descriptions about
how to create custom modules.


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
  gem "spectre-core"
end
```

```bash
$ bundle install
```

For more information about bundler see https://bundler.io

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

You can see the set values of an spectre config, including the environment file by executing

```bash
spectre show
```

See [Spectre::CONFIG](./lib/spectre.rb#L1111-1131) for available options.

All options can also be overridden with the command line argument `-p` or `--property`

```bash
$ spectre -p spec_patterns=some_specific.spec.rb -p mixin_patterns=**/*.my_mixins.rb
```

You can also create a global spectre config file with the options above. 
Create a `spectre.yml` file in your users `.config` directory (`~/config/spectre.yml`) 
and set the options which shall be used for all projects on your computer.


## Writing specs

To write automated tests, just open an editor of your choice and create a file named, 
for example `spooky.spec.rb` in the `specs` folder. Specs are structured in three levels. 
The *subject*, the root context, defined by the keyword `describe`, the actual *specification* defined 
by the `it` keyword and one or more *assertions* or *expectations* described by `assert` or `expect`.
A *subject* can contain one or more *contexts* and/or *specs*.

See [spec example](example/specs/ghostbuster.spec.rb) for an example and more detailed descriptions
on how specs are structured.


## Listing and running specs

To list specs execute

```bash
$ spectre list
```

The output looks like this

```
[ghostbuster-1] Ghostbuster accepts emergency calls #emergency #call #failed #expect #assert
[ghostbuster-2] Ghostbuster while preparing lookups Zuul #entity #location #env
[ghostbuster-3] Ghostbuster while preparing lookups Dream Ghost #entity #location #env
[ghostbuster-4] Ghostbuster hunts at the Sedgewick Hotel #ghosts #success #expect #assert
[ghostbuster-5] Ghostbuster at midnight captures some ghosts #emergency #ghosts #error #group #mixin
[firehouse-1] Firehouse is the home of the Ladder 8 company #trivia
[firehouse-2] Firehouse has a functioning containment unit #fails #observe #expect #assert
```

The name in the brackets is an identifier for a *spec*. This can be used to run only specific *specs*.

```bash
$ spectre -s ghostbuster-1
```

> **Note**
> Note that this ID can change, when more *specs* have been added.


Spec tags are listed with `#`. Those tags can be used to filter specs.

Run specs with one of the listed tags

```bash
$ spectre -t emergency,entity
```

Run specs containing all listed tags

```bash
$ spectre -t emergency+entity
```

Run specs *not* containing specific tags

```bash
$ spectre -t !ghosts
```

You can also use a combination of all

```bash
$ spectre -t emergency,trivia+entity,success+!ghosts
```


## Advanced writing specs

Your project could consist of hundreds and thousand of *specs*. 
In order to easier maintain your project, it is recommended to 
place *specs* of a *subject* in different `*.spec.rb` files and folders, 
grouped by a specific context. A *subject* can be described in multiple files.


### Resource operation testing

For example, when writing *specs* for a REST API, the *specs* could be grouped 
by the APIs *resources* in different folders, and their *operations* in different files.

Specs of a RPC API can be grouped by its functions.

Let's asume we have a *Hollow API* which operates on two resources *ghosts* and *monsters*. 
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

In this case the *resources* can be defined as *subjects*.


### Mixins `spectre/mixin`

You can define reusable specs by using mixins. Create a `.mixin.rb` file 
in the mixin directory (default: `mixins`)

See [mixin example](example/mixins/helpers.mixin.rb) for examples and usage description.
