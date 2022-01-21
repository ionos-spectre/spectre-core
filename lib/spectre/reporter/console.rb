module Spectre::Reporter
  class Console
    def initialize config
      @config = config
    end

    def report run_infos
      report_str = ''

      errors = 0
      failures = 0
      skipped = run_infos.select { |x| x.skipped? }.count

      run_infos
        .select { |x| x.error != nil or x.failure != nil }
        .each_with_index do |run_info, index|
        spec = run_info.spec

        report_str += "\n#{index+1}) #{format_title(run_info)}\n"

        if run_info.failure
          report_str += "     Expected #{run_info.failure.expectation}"
          report_str += " with #{run_info.data}" if run_info.data
          report_str += " during #{spec.context.__desc}" if spec.context.__desc

          report_str += " but it failed"

          if run_info.failure.cause
            report_str += "\n     with an unexpected error:\n"
            report_str += format_exception(run_info.failure.cause)

          elsif run_info.failure.message and not run_info.failure.message.empty?
            report_str += " with:\n     #{run_info.failure.message}"

          else
            report_str += '.'
          end

          report_str += "\n"
          failures += 1

        else
          report_str += "     but an unexpected error occurred during run\n"
          report_str += format_exception(run_info.error)
          errors += 1
        end
      end

      if failures + errors > 0
        summary = ''
        summary += "#{run_infos.length - failures - errors - skipped} succeeded "
        summary += "#{failures} failures " if failures > 0
        summary += "#{errors} errors " if errors > 0
        summary += "#{skipped} skipped " if skipped > 0
        summary += "#{run_infos.length} total"
        print "\n#{summary}\n".red
      else
        summary = ''
        summary = "\nRun finished successfully"
        summary += " (#{skipped} skipped)" if skipped > 0
        print "#{summary}\n".green
      end

      puts report_str.red
    end

    private

    def format_title run_info
      title = run_info.spec.subject.desc
      title += ' ' + run_info.spec.desc
      title += " (#{'%.3f' % run_info.duration}s)"
      title += " [#{run_info.spec.name}]"
      title
    end

    def format_exception error
      non_spectre_files = error.backtrace.select { |x| !x.include? 'lib/spectre' }

      if non_spectre_files.count > 0
        causing_file = non_spectre_files.first
      else
        causing_file = error.backtrace[0]
      end

      matches = causing_file.match(/(.*\.rb):(\d+)/)

      return '' unless matches

      file, line = matches.captures
      file.slice!(Dir.pwd + '/')

      str = ''
      str += "       file.....: #{file}:#{line}\n"
      str += "       type.....: #{error.class}\n"
      str += "       message..: #{error.message}\n"
      str += "       backtrace: \n         #{error.backtrace.join("\n         ")}\n" if @config['debug']
      str
    end
  end
end
