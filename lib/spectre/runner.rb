require 'ostruct'

require_relative 'core'

module Spectre
  class ExpectationFailure < Exception
    attr_reader :expectation

    def initialize message, expectation
      super message
      @expectation = expectation
    end
  end

  class SpectreSkip < Interrupt
  end

  class ExpectationContext < DslBase
    def initialize expectation
      @expectation = expectation
    end

    def fail_with message
      raise ExpectationFailure.new(message, @expectation)
    end
  end

  class RunContext
    def initialize run_info, scope
      @run_info = run_info
      @scope = scope
      @success = nil
      @extensions = {}

      scope.extensions.each do |*methods, factory|
        target = factory.call(self)
        methods.each do |method_name|
          @extensions[method_name] = target
        end
      end
    end

    def env
      @scope.env
    end

    def bag
      @scope.bag
    end

    def fail_with message
      raise ExpectationFailure.new(message, @expectation)
    end

    def expect desc
      status = :unknown
      message = nil

      begin
        @scope.event.trigger(:start_expect, desc, run_info: @run_info)
        yield
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
        @scope.event.trigger(:end_expect, desc, status, message, run_info: @run_info)
        @run_info.expectations.append([desc, status])
      end
    end

    def observe desc = nil
      prefix = 'observing'
      prefix += " '#{desc}'" if desc

      begin
        @scope.event.trigger(:log, prefix, :info, run_info: @run_info) if desc
        yield
        @success = true
        @scope.logger.info("#{prefix} finished with success")
      rescue Interrupt => e
        raise e
      rescue Exception => e
        error_message = "#{prefix} finished with failure: #{e.message}"
        error_message += "\n" + e.backtrace.join("\n")

        @scope.logger.info(error_message)
        @success = false
      end
    end

    def success?
      @success
    end

    def property key, val
      @scope.logger.info("Set property #{key} to #{val}")
      @run_info.properties[key] = val
    end

    def group desc
      @scope.logger.info("Start #{desc}")
      @scope.event.trigger(:group, desc, run_info: @run_info) do
        yield
      end
      @scope.logger.info("Finished #{desc}")
    end

    def skip message=nil
      @scope.logger.info("Skipped #{@run_info.spec.desc}")
      raise SpectreSkip.new(message)
    end

    [:info, :debug, :warn, :error].each do |level|
      define_method(level) do |message|
        @scope.logger.send(level, message)
        @scope.event.trigger(level, message, run_info: @run_info)
      end
    end

    alias_method :log, :info

    def method_missing method, *args, **kwargs, &block
      if @extensions.key? method
        @extensions[method].send(method, *args, **kwargs, &block)
      else
        raise "no method or variable `#{method}' defined"
      end
    end
  end

  class RunInfo
    attr_accessor :spec, :data, :started, :finished, :error, :failure, :skipped
    attr_reader :expectations, :log, :events, :properties

    def initialize scope, spec, data=nil
      @scope = scope
      @spec = spec
      @data = data
      @started = nil
      @finished = nil
      @error = nil
      @failure = nil
      @skipped = false
      @log = []
      @events = []
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
        env: @scope.env.name,
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
    def initialize scope
      @scope = scope
    end

    def run specs
      runs = []

      specs.group_by { |x| x.subject }.each do |subject, subject_specs|
        @scope.event.trigger(:subject, subject) do
          subject_specs.group_by { |x| x.context }.each do |context, context_specs|
            @scope.event.trigger(:context, context) do
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
      run_info = RunInfo.new(@scope, spec)
      @scope.runs << run_info

      run_info.started = Time.now

      @scope.event.trigger(type, run_info: run_info) do
        begin
          RunContext.new(run_info, @scope).instance_eval(&spec.block)

          run_info.finished = Time.now
        rescue ExpectationFailure => e
          run_info.failure = e
        rescue Exception => e
          run_info.error = e
          @scope.event.trigger(:spec_error, e, run_info: run_info)
        end

        run_info.finished = Time.now
      end

      run_info
    end

    def run_spec spec, data=nil
      run_info = RunInfo.new(@scope, spec, data)
      @scope.runs << run_info

      run_info.started = Time.now

      @scope.event.trigger(:start_spec, run_info: run_info)

      begin
        if spec.context.__before_blocks.count > 0
          @scope.event.trigger(:start_before, run_info: run_info)

          spec.context.__before_blocks.each do |block|
            RunContext.new(run_info, @scope).instance_exec(data, &block)
          end

          @scope.event.trigger(:end_before, run_info: run_info)
        end

        RunContext.new(run_info, @scope).instance_exec(data, &spec.block)
      rescue ExpectationFailure => e
        run_info.failure = e
        @scope.logger.error("expected #{e.expectation}, but it failed with: #{e.message}")
      rescue SpectreSkip => e
        run_info.skipped = true
        @scope.event.trigger(:spec_skip, e.message, run_info: run_info)
      rescue Interrupt
        run_info.skipped = true
        @scope.event.trigger(:spec_skip, 'canceled by user', run_info: run_info)
      rescue Exception => e
        run_info.error = e
        @scope.event.trigger(:spec_error, e, run_info: run_info)
        @scope.logger.error(e.message)
      ensure
        if spec.context.__after_blocks.count > 0
          @scope.event.trigger(:start_after, run_info: run_info)

          begin
            spec.context.__after_blocks.each do |block|
              RunContext.new(run_info, @scope).instance_exec(data, &block)
            end

            run_info.finished = Time.now
          rescue ExpectationFailure => e
            run_info.failure = e
          rescue Exception => e
            run_info.error = e
            @scope.event.trigger(:spec_error, e, run_info: run_info)
            @scope.logger.error(e.message)
          end

          @scope.event.trigger(:end_after, run_info: run_info)
        end
      end

      run_info.finished = Time.now

      @scope.event.trigger(:end_spec, run_info: run_info)

      run_info
    end
  end
end