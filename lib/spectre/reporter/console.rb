module Spectre::Reporter
  class Console
    def initialize config
      @config = config
    end

    def report run_infos
      def format_exception error
        file, line = error.backtrace[0].match(/(.*\.rb):(\d+)/).captures
        file.slice!(Dir.pwd + '/')
        str = ''
        str += "       file.....: #{file}\n"
        str += "       line.....: #{line}\n"
        str += "       type.....: #{error.class}\n"
        str += "       message..: #{error.message}\n"
        str
      end

      report_str = ''

      errors = 0
      failures = 0
      skipped = run_infos.select { |x| x.skipped? }.count

      run_infos
        .select { |x| x.error }
        .each_with_index do |run_info, index|

        spec = run_info.spec

        report_str += "\n#{index+1}) #{format_title run_info}\n"

        if run_info.error.is_a? Spectre::ExpectationFailure
          report_str += "     expected #{run_info.error.expectation}"
          report_str += " with #{run_info.data}" if run_info.data
          report_str += " #{spec.context.desc}" if spec.context.desc
          report_str += "\n"

          if !run_info.error.cause
            report_str += "     but it failed with #{run_info.error}\n"
            failures += 1
          else
            report_str += "     but it failed with an unexpected error\n"
            report_str += format_exception(run_info.error.cause)
            errors += 1
          end

        else
          report_str += "     but an unexpected error occured during run\n"
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
      matches = error.backtrace[0].match(/(.*\.rb):(\d+)/)
      return '' unless matches
      file, line = matches.captures
      file.slice!(Dir.pwd + '/')
      str = ''
      str += "       file.....: #{file}\n"
      str += "       line.....: #{line}\n"
      str += "       type.....: #{error.class}\n"
      str += "       message..: #{error.message}\n"
      str
    end
  end
end