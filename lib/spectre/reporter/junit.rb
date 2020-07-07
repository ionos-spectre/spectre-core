# https://www.ibm.com/support/knowledgecenter/en/SSQ2R2_14.1.0/com.ibm.rsar.analysis.codereview.cobol.doc/topics/cac_useresults_junit.html
# https://github.com/windyroad/JUnit-Schema/blob/master/JUnit.xsd

module Spectre::Reporter
  class JUnit
    def initialize config
      @config = config
    end

    def report run_infos
      now = Time.now.getutc
      timestamp = now.strftime('%s')
      datetime = now.strftime('%FT%T%:z')

      xml_str = '<?xml version="1.0" encoding="UTF-8" ?>'
      xml_str += '<testsuites>'

      suite_id = 0

      run_infos.group_by { |x| x.spec.subject }.each do |subject, run_infos|
        failures = run_infos.select { |x| x.spec.error != nil }

        xml_str += '<testsuite package="' + subject.desc + '" id="' + suite_id.to_s + '" name="' + subject.desc + '" timestamp="' + datetime + '" tests="' + run_infos.length.to_s + '" failures="' + failures.length.to_s + '">'
        suite_id += 1

        run_infos.each do |run_info|
          xml_str += '<testcase name="' + run_info.spec.full_desc + '" time="' + ('%.3f' % run_info.duration) + '">'

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
                text = run_info.spec.error.cause.backtrace.join "\n"
              end
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

      Dir.mkdir @config['out_path'] if not Dir.exist? @config['out_path']

      file_path = File.join(@config['out_path'], 'junit.xml')

      File.open(file_path, 'w') do |file|
        file.write(xml_str)
      end
    end
  end
end