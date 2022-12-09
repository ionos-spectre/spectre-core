require 'ostruct'

require_relative '../spectre'
require_relative './environment'

module Spectre
  class ExpectationContext < DslClass
    def initialize expectation
      @expectation = expectation
    end

    def fail_with message
      raise ExpectationFailure.new(message, @expectation)
    end
  end

  class RunContext < DslClass
    attr_reader :bag

    def initialize run_info, logger, eventing, bag
      @run_info = run_info
      @logger = logger
      @eventing = eventing
      @bag = bag
    end

    def expect desc, &block
      status = :unknown
      message = nil

      begin
        @eventing.trigger(:start_expect, desc)
        ExpectationContext.new(desc)._evaluate(&block)
        status = :ok
      rescue Interrupt => e
        status = :skipped
        raise e
      rescue ExpectationFailure => e
        status = :failed
        raise e
      rescue Exception => e
        status = :error
        raise e
      ensure
        @eventing.trigger(:end_expect, desc, status, message)
        @run_info.expectations.append([desc, status])
      end
    end

    def property key, val
      @logger.log("Set property #{key} to #{val}", :info)
      @run_info.properties[key] = val
    end

    def group desc
      @logger.log("Start #{desc}", :info)
      @eventing.trigger(:group, desc) do
        yield
      end
      @logger.log("Finished #{desc}", :info)
    end

    def skip message=nil
      @logger.log("Skipped #{@run_info.spec.desc}", :info)
      raise SpectreSkip.new(message)
    end

    [:info, :debug, :warn, :error].each do |level|
      define_method(level) do |message|
        @run_info.log << [DateTime.now, message, level, nil]
      end
    end

    alias_method :log, :info
  end

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

  class Runner
    def initialize logger, eventing, bag
      @logger = logger
      @eventing = eventing
      @bag = bag
    end

    def self.run specs
      Runner.new.run(specs)
    end

    def run specs
      runs = []

      specs.group_by { |x| x.subject }.each do |subject, subject_specs|
        @eventing.trigger(:subject, subject) do
          subject_specs.group_by { |x| x.context }.each do |context, context_specs|
            @eventing.trigger(:context, context) do
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

      run_info.started = Time.now

      @eventing.trigger(type, run_info) do
        begin
          RunContext.new(run_info, @logger, @eventing, @bag)._evaluate(&spec.block)

          run_info.finished = Time.now
        rescue ExpectationFailure => e
          run_info.failure = e
        rescue Exception => e
          run_info.error = e
          @eventing.trigger(:spec_error, run_info, e)
        end

        run_info.finished = Time.now
      end

      run_info
    end

    def run_spec spec, data=nil
      run_info = RunInfo.new(spec, data)

      run_info.started = Time.now

      @eventing.trigger(:start_spec, run_info)

      begin
        if spec.context.__before_blocks.count > 0
          @eventing.trigger(:start_before, run_info)

          spec.context.__before_blocks.each do |block|
            RunContext.new(run_info, @logger, @eventing, @bag)._execute(data, &block)
          end

          @eventing.trigger(:end_before, run_info)
        end

        RunContext.new(run_info, @logger, @eventing, @bag)._execute(data, &spec.block)
      rescue ExpectationFailure => e
        run_info.failure = e
        @logger.log("expected #{e.expectation}, but it failed with: #{e.message}", :error)
      rescue SpectreSkip => e
        run_info.skipped = true
        @eventing.trigger(:spec_skip, run_info, e.message)
      rescue Interrupt
        run_info.skipped = true
        @eventing.trigger(:spec_skip, run_info, 'canceled by user')
      rescue Exception => e
        run_info.error = e
        raise e
        @eventing.trigger(:spec_error, run_info, e)
        @logger.log(e.message, :error)
      ensure
        if spec.context.__after_blocks.count > 0
          @eventing.trigger(:start_after, run_info)

          begin
            spec.context.__after_blocks.each do |block|
              RunContext.new(run_info, @logger, @eventing, @bag)._evaluate(&block)
            end

            run_info.finished = Time.now
          rescue ExpectationFailure => e
            run_info.failure = e
          rescue Exception => e
            run_info.error = e
            @eventing.trigger(:spec_error, run_info, e)
            @logger.log(e.message, :error)
          end

          @eventing.trigger(:end_after, run_info)
        end
      end

      run_info.finished = Time.now

      @eventing.trigger(:end_spec, run_info)

      run_info
    end
  end
end