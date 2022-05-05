require 'cgi'

# https://llg.cubic.org/docs/junit/
# Azure mappings: https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/test/publish-test-results?view=azure-devops&tabs=junit%2Cyaml

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

      run_infos.group_by { |x| x.spec.subject }.each do |subject, info_group|
        failures = info_group.select { |x| x.failure != nil }
        errors = info_group.select { |x| x.error != nil }
        skipped = info_group.select { |x| x.skipped? }

        xml_str += '<testsuite package="' + CGI::escapeHTML(subject.desc) + '" id="' + CGI::escapeHTML(suite_id.to_s) + '" name="' + CGI::escapeHTML(subject.desc) + '" timestamp="' + datetime + '" tests="' + run_infos.count.to_s + '" failures="' + failures.count.to_s + '" errors="' + errors.count.to_s + '" skipped="' + skipped.count.to_s + '">'
        suite_id += 1

        info_group.each do |run_info|
          xml_str += '<testcase classname="' + CGI::escapeHTML(run_info.spec.file.to_s) + '" name="' + CGI::escapeHTML(run_info.spec.desc) + '" timestamp="' + run_info.started.to_s + '"  time="' + ('%.3f' % run_info.duration) + '">'

          if run_info.failure and !run_info.failure.cause
            failure_message = "Expected #{run_info.failure.expectation}"
            failure_message += " with #{run_info.data}" if run_info.data

            if run_info.failure.message
              failure_message += " but it failed with #{run_info.failure.message}"
            else
              failure_message += " but it failed"
            end

            xml_str += '<failure message="' + CGI::escapeHTML(failure_message.gsub('"', '`')) + '"></failure>'
          end


          if run_info.error or (run_info.failure and run_info.failure.cause)
            error = run_info.error || run_info.failure.cause

            type = error.class.name
            failure_message = error.message
            text = error.backtrace.join "\n"

            xml_str += '<error message="' + CGI::escapeHTML(failure_message.gsub('"', '`')) + '" type="' + type + '">'
            xml_str += '<![CDATA[' + text + ']]>'
            xml_str += '</error>'
          end


          if run_info.log.count > 0 or run_info.properties.count > 0 or run_info.data
            xml_str += '<system-out>'
            xml_str += '<![CDATA['

            if run_info.properties.count > 0
              run_info.properties.each do |key, val|
                xml_str += "#{key}: #{val}\n"
              end
            end

            if run_info.data
              data_str = run_info.data
              data_str = run_info.data.inspect unless run_info.data.is_a? String or run_info.data.is_a? Integer
              xml_str += "data: #{data_str}\n"
            end

            if run_info.log.count > 0
              messages = run_info.log.map { |x| "[#{x[0].strftime('%F %T')}] #{x[1]}" }
              xml_str += messages.join("\n")
            end

            xml_str += ']]>'
            xml_str += '</system-out>'
          end

          xml_str += '</testcase>'
        end

        xml_str += '</testsuite>'
      end

      xml_str += '</testsuites>'

      Dir.mkdir @config['out_path'] unless Dir.exist? @config['out_path']

      file_path = File.join(@config['out_path'], "spectre-junit_#{timestamp}.xml")

      File.write(file_path, xml_str)
    end
  end
end
