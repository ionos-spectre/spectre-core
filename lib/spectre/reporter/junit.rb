# https://www.ibm.com/support/knowledgecenter/en/SSQ2R2_14.1.0/com.ibm.rsar.analysis.codereview.cobol.doc/topics/cac_useresults_junit.html

module Spectre::Reporter
  class JUnit
    def initialize config
      @config = config
    end

    def report run_infos
      xml_str = '<?xml version="1.0" encoding="UTF-8" ?>'
      xml_str += '<testsuites name="Spectre test" tests="' + run_infos.length.to_s + '">'

      run_infos.group_by { |x| x.spec.subject }.each do |subject, run_infos|
        xml_str += '<testsuite id="' + subject.name + '" name="' + subject.desc + '" tests="' + run_infos.length.to_s + '">'

        run_infos.each do |run_info|
          xml_str += '<testcase id="' + run_info.spec.name + '" name="' + run_info.spec.desc + '" time="' + ('%.3f' % run_info.duration) + '">'

          if run_info.spec.error
            text = nil

            if run_info.spec.error.cause
              if run_info.spec.error.cause.is_a? Spectre::ExpectationFailure
                failure = "Expected #{run_info.spec.error}"
                failure += " with #{run_info.data}" if run_info.data

                if run_info.spec.error.cause.failure
                  failure += " but it failed with #{run_info.spec.error.cause.failure}"
                else
                  failure += " but it failed"
                end

                type = 'FAILURE'
              else
                failure = run_info.spec.error.cause.message
                type = 'ERROR'
              end

              text = run_info.spec.error.cause.backtrace.join "\n"
            else
              failure = run_info.spec.error.message
              type = 'ERROR'
              text = run_info.spec.error.backtrace.join "\n"
            end

            xml_str += '<failure message="' + failure.gsub('"', '`') + '" type="' + type + '">'
            xml_str += '<![CDATA[' + text + ']]>' if text
            xml_str += '</failure>'
          end

          xml_str += '</testcase>'
        end

        xml_str += '</testsuite>'
      end

      xml_str += '</testsuites>'

      file_path = File.join(@config['out_path'], 'junit.xml')

      File.open(file_path, 'w') do |file|
        file.write(xml_str)
      end
    end
  end
end