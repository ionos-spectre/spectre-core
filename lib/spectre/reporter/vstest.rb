require 'cgi'
require 'socket'
require 'securerandom'

# Azure mappings: https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/test/publish-test-results?view=azure-devops&tabs=trx%2Cyaml

module Spectre::Reporter
  class VSTest
    def initialize config
      @config = config
      @date_format = '%FT%T.%L'
    end

    def report run_infos
      now = Time.now.getutc

      xml_str = '<?xml version="1.0" encoding="UTF-8" ?>'
      xml_str += %{<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">}

      started = run_infos[0].started
      finished = run_infos[-1].finished

      computer_name = Socket.gethostname

      xml_str += %{<Times start="#{started.strftime(@date_format)}" finish="#{finished.strftime(@date_format)}" />}


      # Write summary with file attachments
      xml_str += '<ResultSummary>'
      xml_str += '<ResultFiles>'
      xml_str += %{<ResultFile path="#{File.absolute_path(@config['log_file'])}"></ResultFile>} if File.exists? @config['log_file']

      report_files = Dir[File.join(@config['out_path'], '*')]

      if report_files.any?
        report_files.each do |report_file|
          xml_str += %{<ResultFile path="#{File.absolute_path(report_file)}"></ResultFile>}
        end
      end

      xml_str += '</ResultFiles>'
      xml_str += '</ResultSummary>'


      # Write test definitions
      test_definitions = run_infos
        .sort_by { |x| x.spec.name }
        .map { |x| [SecureRandom.uuid(), SecureRandom.uuid(), x] }

      xml_str += '<TestDefinitions>'
      test_definitions.each do |test_id, execution_id, run_info|
        xml_str += %{<UnitTest name="#{CGI::escapeHTML get_name(run_info)}" storage="#{CGI::escapeHTML(run_info.spec.file.to_s)}" id="#{test_id}">}
        xml_str += %{<Execution id="#{execution_id}" />}
        xml_str += '</UnitTest>'
      end
      xml_str += '</TestDefinitions>'


      # Write test results
      xml_str += '<Results>'
      test_definitions.each do |test_id, execution_id, run_info|
        duration_str = Time.at(run_info.duration).gmtime.strftime('%T.%L')

        if run_info.failed?
          outcome = 'Failed'
        elsif run_info.error?
          outcome = 'Error'
        elsif run_info.skipped?
          outcome = 'Skipped'
        else
          outcome = 'Passed'
        end

        xml_str += %{<UnitTestResult executionId="#{execution_id}" testId="#{test_id}" testName="#{CGI::escapeHTML get_name(run_info)}" computerName="#{computer_name}" duration="#{duration_str}" startTime="#{run_info.started.strftime(@date_format)}" endTime="#{run_info.finished.strftime(@date_format)}" outcome="#{outcome}">}

        if run_info.log.any? or run_info.failed? or run_info.error?
          xml_str += '<Output>'

          # Write log entries
          xml_str += '<StdOut>'
          log_str = ''
          run_info.log.each do |timestamp, message, level, name|
            log_str += %{#{timestamp.strftime(@date_format)} #{level.to_s.upcase} -- #{name}: #{CGI::escapeHTML(message.to_s)}\n}
          end
          xml_str += log_str
          xml_str += '</StdOut>'

          # Write error information
          if run_info.failed? or run_info.error?
            xml_str += '<ErrorInfo>'

            if run_info.failed? and not run_info.failure.cause
              xml_str += '<Message>'

              failure_message = "Expected #{run_info.failure.expectation}"
              failure_message += " with #{run_info.data}" if run_info.data
              failure_message += " but it failed"
              failure_message += " with message: #{run_info.failure.message}" if run_info.failure.message

              xml_str += CGI::escapeHTML(failure_message)

              xml_str += '</Message>'
            end

            if run_info.error or (run_info.failed? and run_info.failure.cause)
              error = run_info.error || run_info.failure.cause

              failure_message = error.message

              xml_str += '<Message>'
              xml_str += CGI::escapeHTML(failure_message)
              xml_str += '</Message>'

              stack_trace = error.backtrace.join "\n"

              xml_str += '<StackTrace>'
              xml_str += CGI::escapeHTML(stack_trace)
              xml_str += '</StackTrace>'
            end

            xml_str += '</ErrorInfo>'
          end

          xml_str += '</Output>'
        end


        xml_str += '</UnitTestResult>'
      end
      xml_str += '</Results>'


      # End report
      xml_str += '</TestRun>'


      Dir.mkdir(@config['out_path']) unless Dir.exists? @config['out_path']

      file_path = File.join(@config['out_path'], "spectre-vstest_#{now.strftime('%s')}.trx")

      File.write(file_path, xml_str)
    end

    private

    def get_name run_info
      run_name = "[#{run_info.spec.name}] #{run_info.spec.subject.desc}"
      run_name += " - #{run_info.spec.context.__desc} -" unless run_info.spec.context.__desc.nil?
      run_name += " #{run_info.spec.desc}"
      run_name
    end
  end
end
