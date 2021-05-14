
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