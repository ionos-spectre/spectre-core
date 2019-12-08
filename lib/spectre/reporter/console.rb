module Spectre::Reporter
  class Console
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

      run_infos
        .select { |x| x.spec.error }
        .each_with_index do |run_info, index|
        
        subject = run_info.subject
        spec = run_info.spec

        report_str += "\n#{index+1}) #{format_title run_info}\n"
      
        if spec.error.cause
          report_str += "     expected #{spec.error}\n"
      
          if spec.error.cause.is_a? Spectre::ExpectationFailure
            failure = spec.error.cause.failure || 'nil'
            report_str += "     but it failed with #{failure}\n"
            failures += 1
          else
            report_str += "     but it failed with an unexpected error\n"
            report_str += format_exception(spec.error.cause)
            errors += 1
          end
      
        else
          report_str += "     but an unexpected error occured during run\n"
          report_str += format_exception(spec.error)
          errors += 1
        end
      end

      if failures + errors > 0
        summary = ''
        summary += "#{run_infos.length - failures - errors} succeeded "
        summary += "#{failures} failures " if failures > 0
        summary += "#{errors} errors " if errors > 0
        summary += "#{run_infos.length} total"
        print "\n#{summary}\n".red
      else
        print "\nRun finished successfully\n".green
      end

      puts report_str.red
    end
    
    private 

    def format_title run_info
      title = run_info.subject.desc
      title += ' ' + run_info.spec.desc
      title += " (#{'%.3f' % run_info.duration}s)"
      title += " [#{run_info.spec.id}]"
      title
    end

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
  end
end