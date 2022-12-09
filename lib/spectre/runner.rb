require 'ostruct'

require_relative './environment'

module Spectre
  module Runner
    class RunInfo
      attr_accessor :spec, :data, :started, :finished, :error, :failure, :skipped
      attr_reader :expectations, :log, :properties

      def initialize spec, data=nil
        @spec = spec
        @data = data
        @started = nil
        @finished = nil
        @error = nil
        @failure = nil
        @skipped = false
        @log = []
        @expectations = []
        @properties = {}
      end

      def duration
        @finished - @started
      end

      def skipped?
        @skipped
      end

      def failed?
        @failure != nil
      end

      def error?
        @error != nil
      end

      def success?
        @error == nil && @failure == nil
      end

      def status
        return :queued unless @started
        return :running if @started and not @finished
        return :error if error?
        return :failed if failed?
        return :skipped if skipped?

        return :success
      end

      def to_h
        date_format = '%FT%T.%L%:z'

        {
          spec: @spec.name,
          data: @data,
          started: @started.nil? ? nil : @started.strftime(date_format),
          finished: @finished.nil? ? nil : @finished.strftime(date_format),
          error: @error,
          failure: @failure,
          skipped: @skipped,
          status: status,
          log: @log.map { |timestamp, message, level| [timestamp.strftime(date_format), message, level] },
          expectations: @expectations,
          properties: @properties,
        }
      end
    end

    class << self
      def current
        Environment.bucket(:spectre_run)
      end

      def current= run
        Environment.put(:spectre_run, run)
      end

      def run specs
        runs = []

        specs.group_by { |x| x.subject }.each do |subject, subject_specs|
          Eventing.trigger(:subject, subject) do
            subject_specs.group_by { |x| x.context }.each do |context, context_specs|
              Eventing.trigger(:context, context) do
                runs.concat run_context(context, context_specs)
              end
            end
          end
        end

        runs
      end

      private

      def run_context context, specs
        runs = []

        context.__setup_blocks.each do |setup_spec|
          setup_run = run_setup(setup_spec, :setup)
          runs << setup_run
          return runs unless setup_run.success?
        end

        begin
          specs.each do |spec|
            raise SpectreError.new("Multi data definition (`with' parameter) of '#{spec.subject.desc} #{spec.desc}' has to be an `Array'") unless !spec.data.nil? and spec.data.is_a? Array

            if spec.data.any?
              spec.data
                .map { |x| x.is_a?(Hash) ? OpenStruct.new(x) : x }
                .each do |data|
                  runs << run_spec(spec, data)
                end
            else
              runs << run_spec(spec)
            end
          end
        ensure
          context.__teardown_blocks.each do |teardown_spec|
            runs << run_setup(teardown_spec, :teardown)
          end
        end

        runs
      end

      def run_setup spec, type
        run_info = RunInfo.new(spec)

        Runner.current = run_info

        run_info.started = Time.now

        Eventing.trigger(('start_' + type.to_s).to_sym, run_info)

        begin
          spec.block.call()

          run_info.finished = Time.now
        rescue ExpectationFailure => e
          run_info.failure = e
        rescue Exception => e
          run_info.error = e
          Eventing.trigger(:spec_error, run_info, e)
        end

        run_info.finished = Time.now

        Eventing.trigger(('end_' + type.to_s).to_sym, run_info)

        Runner.current = nil

        run_info
      end

      def run_spec spec, data=nil
        run_info = RunInfo.new(spec, data)

        Runner.current = run_info

        run_info.started = Time.now

        Eventing.trigger(:start_spec, run_info)

        begin
          if spec.context.__before_blocks.count > 0
            Eventing.trigger(:start_before, run_info)

            spec.context.__before_blocks.each do |block|
              block.call(data)
            end

            Eventing.trigger(:end_before, run_info)
          end

          spec.block.call(data)
        rescue ExpectationFailure => e
          run_info.failure = e
          Logging.log("expected #{e.expectation}, but it failed with: #{e.message}", :error)
        rescue SpectreSkip => e
          run_info.skipped = true
          Eventing.trigger(:spec_skip, run_info, e.message)
        rescue Interrupt
          run_info.skipped = true
          Eventing.trigger(:spec_skip, run_info, 'canceled by user')
        rescue Exception => e
          run_info.error = e
          Eventing.trigger(:spec_error, run_info, e)
          Logging.log(e.message, :error)
        ensure
          if spec.context.__after_blocks.count > 0
            Eventing.trigger(:start_after, run_info)

            begin
              spec.context.__after_blocks.each do |block|
                block.call
              end

              run_info.finished = Time.now
            rescue ExpectationFailure => e
              run_info.failure = e
            rescue Exception => e
              run_info.error = e
              Eventing.trigger(:spec_error, run_info, e)
              Logging.log(e.message, :error)
            end

            Eventing.trigger(:end_after, run_info)
          end
        end

        run_info.finished = Time.now

        Eventing.trigger(:end_spec, run_info)

        Runner.current = nil

        run_info
      end
    end
  end
end