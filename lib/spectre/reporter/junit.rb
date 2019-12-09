# https://www.ibm.com/support/knowledgecenter/en/SSQ2R2_14.1.0/com.ibm.rsar.analysis.codereview.cobol.doc/topics/cac_useresults_junit.html

module Spectre::Reporter
  class JUnit
    def report run_infos
      xml_str = '<?xml version="1.0" encoding="UTF-8" ?>'
      xml_str += '<testsuites id="" name="" tests="" failures="" time="">'

      run_infos.group_by { |x| x.subject }.each do |subject, run_infos|
        xml_str += '<testsuite id="' + subject.name + '" name="' + subject.desc + '" tests="' + subject.specs.length.to_s + '" failures="" time="">'

        run_infos.each do |run_info|
          xml_str += '<testcase id="' + run_info.spec.name + '" name="' + run_info.spec.desc + '" time="' + ('%.3f' % run_info.duration) + '">'

          if run_info.spec.error
            if run_info.spec.error.cause
              if run_info.spec.error.cause.is_a? Spectre::ExpectationFailure
                failure = "failed with #{run_info.spec.error.cause.failure || 'nil'}"
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
            xml_str += '<failure message="' + failure + '" type="' + type + '">'
            xml_str += '<![CDATA[' + text + ']]>'
            xml_str += '</failure>'
          end

          xml_str += '</testcase>'
        end

        xml_str += '</testsuite>'
      end

      xml_str += '</testsuites>'

      File.open('report.xml', 'w') do |file|
        file.write(xml_str)
      end
    end
  end
end