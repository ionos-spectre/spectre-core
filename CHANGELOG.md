### v2.1.1

#### Minor
 - Fixes a bug where an `assert` in the after block aborts the run, even when the assert was successful.

### v2.1.0

#### Major
 - Environment listing via command line added. Use `spectre envs` to list available environments.
 - Added `context` attribute to `RunInfo`.
 - Subject (`subj`) and context (`ctxt`) description added to spec listing with JSON formatter.

### v2.0.3

#### Minor
 - Log filename placeholder are now replaced on setup and not when logger is initialized, so final log filename can be used by module initialization.

### v2.0.2

#### Minor
 - Module loading has been fixed, when additional modules were defined with command line arguments.

### v2.0.1

#### Minor
 - Use absolute paths when loading spec and mixin files
 - Listing mixins in JSON format added

### v2.0.0

#### Breaking Changes
 - `expect` does not abort the test run. Use `assert` instead.
 - Data type is considered when using `should_be`syntax. So `'42'.should_be 42` is not true anymore.
 - `spectre/http` module has been extracted into new repository. See https://github.com/ionos-spectre/spectre-http
 - `spectre/curl` was removed completely.

#### Major
 - New command line option are available. See `spectre -h` for options and details.
 - New assertion syntax available. Run `bundle exec rdoc` for detailed documentation.
    - `assert` will end the test run, when a failure occured. `expect` will only report the error, but the run continues.
    - Single line assertion is now possible, like `assert foo.to be 'bar'`. No block needed anymore.
    - In order to report failures within `assert` or `expect`, use `report <string>` (instead of `fail_with`)
    - `fail_with` is *deprecated*
 - New detailed documentation is available. Run `bundle exec rdoc` to generate documentatino. Generated files are located at `doc/index.html`.
 - JSON formatter added. Use `spectre --json` to get JSON output of logs and reports.

### v1.15.2

#### Major
 - `assert` was added as an alias for `expect`. Use `assert` from now on to have the same behavior with spectre v2
 - Module loading was updated. The `include` option in `spectre.yml` is replaced by `modules`. `include` will still work and no adjustments are necessary.
 - Resource class has now the `.key?` method.
 - Latest `ectoplasm` gem is used and `--no-color` option was removed.

### v1.14.2

#### Minor
 - Refactor `uuid` generation. The helper method `uuid` will now return a GUID by default, when no length is given.
 - Fix assertions

### v1.14.1

#### Minor
 - Value comparision of `should_be` is now done by calling `.to_s` on both values.

### v1.14.0

#### Major
 - `spectre/reporter/junit` reporter module was extracted into a separate gem. See https://github.com/ionos-spectre/spectre-reporter-junit
 - `spectre/reporter/vstest` reporter module was extracted into a separate gem. See https://github.com/ionos-spectre/spectre-reporter-vstest
 - `spectre/reporter/html` reporter module was extracted into a separate gem. See https://github.com/ionos-spectre/spectre-reporter-html

#### Minor
 - Set `application/json` content, when `json()` in `http` module is called, only if `content_type` was not set before
 - `-m --modules` parameter was added. This parameter lets you load additional modules before running spectre, e.g. load reporter module like `spectre/reporter/html`, which is not included in the `spectre-core` library.
 - `or` and `and` evaluation refactored and fixed. `or` and `and` did not work properly in combination with eachother.
 - Log truncation for HTTP requests removed
 - `no_log!` function for `http` module added, in order to ommit body logging for large content

### v1.13.0

### Major
 - `spectre/async` module added. See _Async `spectre/async`_ section in `README.md` for more information.
 - `spectre/reporter/vstest` report added. This reporter writes Visual Studio Test (TRX) reports
 - `spectre/reporter/html` report added. Creates an interactive HTML report for sharing and analyzing test results.

#### Minor
 - `Array.first_element` added to be consistent with `Array.last_element`, which was added because some libraries override `Array.last` which caused some issues.
 - Updated the run info name in the JUnit report. It now contains spec name and context name

### v1.12.4

#### Major
 - `Dockerfile` fixed and updated. It will now build with all Spectre modules.
 - Changed Ruby requirement to Ruby >= v3.0.0
 - `skip` feature implemented. Spec runs can now be skipped by calling `skip <message>`.

#### Minor
 - `cgi` package loading fixt for linux systems

### v1.12.3

#### Major
 - `spectre cleanup` command added. This command will delete all log files and file in `out_path` directory (e.g. reports).

#### Minor
 - Property override fixed
 - Spec descriptions are now HTML escaped in JUnit reports


### v1.12.2

#### Minor
 - HTTP `max_retry` set to 0 by default and added `retries` property to HTTP module to make it configurable
 - HTTP default value setting fixed
 - Certifcate `nil` value error fixed. When `cert` was set to `nil` a error occured, instead of ignoring the `cert` setting.


### v1.12.1

#### Minor
 - Custom spectre error class added. Will be raised on general spectre errors.
 - Line number added to filepath in exception report
 - Some expectation failure messages updated


### v1.12.0

### Major
 - Returning a `Hash` from a mixin, converts `Hash` to `OpenStruct`
 - `Array.last` was renamed to `Array.last_element` as it conflicts with existing method in other modules

#### Minor
 - New mixin methods for defining `required` and `optional` parameters added. `optional` parameters are just logged and are used for documentation only.
 - Result logging for `observe` added
 - HTTP `read_timeout` made configurable via `timeout` method and property in yml file and default value set to 180s
 - Added new functions `started_at` and `finished_at` to `spectre/diagnostic`
 - Added `started_at` and `finished_at` property to `request` object
 - `request` and `response` are now immutable
 - Some code cleanup
 - Bugfix: `https` is now working correctly
 - Added `should_be_empty` and `should_not_be_empty` to `Hash` and `OpenStruct`
 - Bugfix: Keystone function is now working
 - Request with invalid or not available server is now generating a more useful error message
 - Bugfix: HTTP config is not modified anymore, when requesting and changing parameters within one run
 - `no_auth!` method added to `http` module, to reset authentication method
 - Configuring a certificate does not automatically activate HTTP anymore


### v1.11.0

#### Major
 - Helpers methods and functions added
   - `string.as_timestamp` is now available. Parses a string a unix timestamp
   - `string.file_size` is now available. Interprets string as file path and gives back the file size if the file exists.
   - `now` returns the current time (like `Time.now`)
   - `array.last` method added. Returns the last element of a list.
   - `Hash.default_to!` and `OpenStruct.default_to!` method added. Sets default values, when value in Hash is `nil` or key does not exist.
 - Mixins take always at least one parameter. If a mixin is called with `run '<mixin>' with: nil`, the mixin parameter is an empty `Hash`.
 - Passing a `Hash` to the `run` method of mixins, will pass the `Hash` parameter as an `OpenStruct` to the mixin


### v1.10.0

#### Major
 - JsonPath function added. You can now use `.pick(<string>)` on `String`, `Hash` and `OpenStruct` to use JsonPath selection. For more information on JsonPath see https://goessner.net/articles/JsonPath/

#### Minor
 - HTTP logging of non JSON responses is fixed
 - When `--debug` mode is set, the complete backtrace will be put in the console report


### v1.9.0

#### Major
 - The docker image is now based on alpine linux, which is 10 times smaller, than the previous spectre image
 - Some modules were removed from the core project and are available as separate gem packages
   - `spectre/mysql` moved to https://github.com/ionos-spectre/spectre-mysql
   - `spectre/ssh` moved to https://github.com/ionos-spectre/spectre-ssh
   - `spectre/ftp` moved to https://github.com/ionos-spectre/spectre-ftp

#### Minor
 - Added placeholder substitution function to `String` (`with(Hash)`)
 - Bugfixes. `trim` and `uuid` generate now the correct amount of characters
 - `--ignore-failure` options added. When set, `spectre` always exits with exit code 0
 - HTTP logging fixed. Now, all request headers are being logged.
 - Secure keys added. You can now define define `secure_keys` in you `spectre.yml`. These keys are used to obfuscate sensitive values in log files, like HTTP headers values or JSON data. It will be checked if one of the given secure keys is *contained* in the header or JSON key, e.g. the secure key `token` will obfuscate a HTTP header with key `X-Auth-Token`. The check is case-insensitive.
 - The output path `-o` is no longer relative to execution directory.
 - Bugfix: non-existing HTTP headers do not throw an exception anymore
 - Environment name is now available in `env` module


### v1.8.4

#### Minor
 - External installed module loading added


### v1.8.2

#### Minor
 - `spectre` does no longer crash, when a parent of a log path does not exist


### v1.8.1

#### Minor
 - `-r` (`--reporter`) options fixed to match new reporter config. `-r` is now a list parameter and can take multiple reporters e.g. `-r Spectre::Reporter::JUnit,Spectre::Reporter::Console`


### v1.8.0

### Major
 - Reporting is reworked. You can now configure multiple reporters at once.
 - `property(key, value)` function added. Use this function to add run properties, which will be contained in the report.

#### Minor
 - Error report now includes the causing spec file, instead of the most recent file.
 - Some error message optimizations


### v1.7.4

#### Minor
 - `curl` output parsing fixed. Linux uses `\r\n\r\n`, whereas Windows has `\n\n` line endings on `stdout`.


### v1.7.3

#### Minor
 - `sftp` made non-interactive


### v1.7.2

#### Minor
 - `ssh` made non-interactive


### v1.7.1

#### Minor
 - `as_json` returns now a `OpenStruct` instead of a `Hash`


### v1.7.0

#### Major
 - Added `spectre dump` to command line tool. Dumps the given environment in YAML format to console output
 - Global config added. When the `~/.spectre` exists, it will always be read as a spectre config (like `spectre.yml`).
 - Log customization options added
 - `check` function removed and `observe` reworked. `observe` does not throw an exception anymore, but saves the success status, which is available with `success?`
 - `http` module recovered. `curl` is now a speparate function and responses can be accessed with `curl_response`
 - Implemented OR and AND assertions. See `spectre/assertion` section in `README.md` for more infos


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
 - HTTP module refactored. See _HTTP_ section in `README.md`.

#### Minor
 - Partial environment files added. See _Environment_ section in `README.md`.
 - Debug logging added. use `debug 'some info text'` to create debug log entries in files and console output
 - `log_level` config property added. When set to `DEBUG`, additional `spectre` log will be written.
 - Duplicate environment definition check added. When there are more than one environments defined with the same name in different files, spectre will not continue executing.
 - Method delegation fixed. For example, it is now possible to use `response` within other `http` blocks for refering to a previous HTTP response.
 - Mixins can now be executed with `run`, `step` or `also`
 - Small bugfixes
