# frozen_string_literal: true

require 'ostruct'
require 'yaml'
require 'json'
require 'optparse'
require 'ectoplasm'
require 'date'
require 'fileutils'
require 'securerandom'
require 'logger'
require 'stringio'

require_relative 'spectre/version'
require_relative 'spectre/assertion'
require_relative 'spectre/helpers'

def get_call_location call_stack
  loc = (call_stack || caller_locations)
    .find { |x| x.label.include? 'Spectre::Engine#load_files' or x.base_label == '<top (required)>' }

  [
    loc.path.sub(Dir.pwd, '.'),
    loc.lineno
  ]
end

class Hash
  # :nodoc:
  def deep_merge!(second)
    return unless second.is_a?(Hash)

    merger = proc { |_key, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge!(v2, &merger) : v2 }
    merge!(second, &merger)
  end

  # :nodoc:
  def to_recursive_struct
    OpenStruct.new(
      transform_values do |val|
        case val
        when Hash, Array
          val.to_recursive_struct
        else
          val
        end
      end
    )
  end
end

class Array
  # :nodoc:
  def to_recursive_struct
    map(&:to_recursive_struct)
  end
end

class Object
  # :nodoc:
  def to_recursive_struct
    self
  end
end

class String
  alias error   red
  alias failed  red
  alias fatal   red
  alias warn    yellow
  alias ok      green
  alias info    blue
  alias debug   grey
  alias skipped grey
end

##
# The main module containing all logic for the framework
#
module Spectre
  ##
  # Exception to throw in order to abort a spec run
  #
  class AbortException < StandardError
  end

  ##
  # Extension methods used by Spectre modules to expose
  # registered methods in all Spectre and module scopes.
  #
  module Delegate
    @@methods = {}

    def instance_eval &block
      @outer_scope = eval('self', block.binding)
      super
    end

    def instance_exec(*, **, &block)
      @outer_scope = eval('self', block.binding)
      super
    end

    def respond_to_missing?(method, *)
      @engine.respond_to?(method) or
        @outer_scope.respond_to?(method)
    end

    def method_missing(method, *, &)
      return @engine.send(method, *, &) if @engine.respond_to?(method)
      return @outer_scope.send(method, *, &) if @outer_scope.respond_to?(method)

      super
    end
  end

  ##
  # The failure class containing information about spec failures
  # created by +assert+ and +expect+.
  #
  class Failure < StandardError
    # A message describing the failure
    attr_reader :message
    # The file path where the failure occured
    attr_reader :file
    # The line where the failure occured
    attr_reader :line

    ##
    # Constructs a new +Failure+ instance with the given message
    # and determines the +file+ and +line+ from the given call stack
    def initialize message, call_stack = nil
      super(message)

      @file, @line = get_call_location(call_stack || caller_locations)
      @message = message
    end

    # :nodoc:
    def to_s
      "#{@message} - in #{@file}:#{@line}"
    end
  end

  ##
  # This context will be created by +assert+ and +expect+
  # methods. Failures are reported here.
  #
  class EvaluationContext
    include Delegate

    attr_reader :desc, :failures

    def initialize(engine, desc, &)
      @desc = desc
      @failures = []

      engine.formatter.log(:info, desc) do
        instance_eval(&)

        if @failures.any?
          engine.logger.error("#{desc} - failed")
          [:error, :failed, nil]
        else
          engine.logger.info("#{desc} - ok")
          [:info, :ok, nil]
        end
      rescue Failure => e
        engine.logger.error("#{e.message} - failed")
        @failures << e
        [:error, :failed, nil]
      end
    end

    ##
    # Report a failure with the +EvaluationContext+.
    #
    def report failure
      @failures << Failure.new(failure, caller_locations)
    end
  end

  ##
  # An extended +Logger+ class providing additional Spectre run information
  #
  class Logger < ::Logger
    def initialize(config, **)
      log_file = config['log_file']

      if log_file.is_a? String
        log_file = log_file.gsub('<date>', DateTime.now.strftime('%Y-%m-%d_%H%M%S%3N'))
        FileUtils.mkdir_p(File.dirname(log_file))
      end

      super(log_file, **)

      if config['debug']
        debug!
      else
        info!
      end

      @corr_ids = []

      @formatter = proc do |severity, datetime, progname, message|
        date_formatted = datetime.strftime(config['log_date_format'])
        progname ||= 'spectre'

        corr_id = @corr_ids.join

        # Add log message also to the current executing run context
        if RunContext.current.nil?
          context_name = 'spectre'
        else
          RunContext.current.logs << [date_formatted, severity, progname, corr_id, message]
          context_name = RunContext.current.name
        end

        format(config['log_message_format'],
               date_formatted,
               severity,
               progname,
               context_name,
               corr_id,
               message)
      end
    end

    def correlate
      @corr_ids.append(rand(36**4).to_s(36))

      begin
        yield
      ensure
        @corr_ids.pop
      end
    end
  end

  class SimpleFormatter
    def initialize config
      @out = config['stdout'] || $stdout
      @level = 0
      @width = 80
      @indent = 2
      @colors = [:blue, :magenta, :yellow, :green]
      @debug = config['debug']
    end

    ##
    # Formats a list of specs in short form
    #
    def list specs
      counter = 0

      specs
        .group_by { |x| x.parent.root }
        .each_value do |spec_group|
          spec_group.sort_by!(&:name)
          spec_group.each do |spec|
            spec_id = "[#{spec.name}]".send(@colors[counter % @colors.length])
            @out.puts "#{spec_id} #{spec.full_desc} #{spec.tags.map { |x| "##{x}" }.join(' ').cyan}"
          end

          counter += 1
        end
    end

    ##
    # Outputs all the specs for all contexts
    #
    def describe contexts, level = 0
      contexts.each do |context|
        @out.puts("#{'  ' * level}#{context.desc.send(level.positive? ? :magenta : :blue)}")

        context.specs.each do |spec|
          @out.puts("#{'  ' * (level + 1)}#{spec.desc}")
        end

        describe(context.children, level + 1)
      end
    end

    ##
    # Formats the details of given specs
    #
    def details specs
      counter = 0

      specs
        .group_by { |x| x.parent.root }
        .each_value do |spec_group|
          spec_group.each do |spec|
            spec_id = "[#{spec.name}]".send(@colors[counter % @colors.length])
            spec_detail  = "#{spec_id}\n"
            spec_detail += "  subject..: #{spec.root.desc}\n"
            spec_detail += "  context..: #{spec.parent.desc}\n" unless spec.root == spec.parent
            spec_detail += "  desc.....: #{spec.desc}\n"
            spec_detail += "  tags.....: #{spec.tags.join(', ')}\n" if spec.tags.any?
            spec_detail += "  data.....: #{spec.data.to_json}\n" if spec.data
            spec_detail += "  file.....: #{spec.file}\n"

            @out.puts("#{spec_detail}\n")
          end

          counter += 1
        end
    end

    ##
    # Formats a list of mixins
    #
    def mixins mixins
      paragraphs = []

      mixins.each_value do |mixin|
        output  = "#{mixin.desc.yellow}\n"
        output += "  params.....: #{mixin.params.join ', '}\n" if mixin.params.any?
        output += "  location...: #{mixin.file.sub(Dir.pwd, '.')}:#{mixin.line}"
        paragraphs << output
      end

      @out.puts paragraphs.join("\n\n")
    end

    def collections engine
      @out.puts engine.collections.pretty
    end

    def environment env
      @out.puts env.to_h.pretty
    end

    def scope desc, type
      if desc
        colored_desc = case type
                       when :before, :after, :setup, :teardown
                         desc.magenta
                       when :group
                         desc.grey
                       when Specification
                         desc.cyan
                       when :mixin
                         desc.yellow
                       when DefinitionContext
                         desc.blue
                       else
                         desc
                       end

        write(colored_desc)

        @out.puts "\n"
      end

      return unless block_given?

      @level += 1

      begin
        yield
      ensure
        @level -= 1
      end
    end

    def log level, message, status = nil, desc = nil
      return if @locked

      color = [:fatal, :debug].include?(level) ? level : nil

      write(message, fill: true, color:) if block_given? or @debug or level != :debug

      error = nil

      if block_given?
        @locked = true

        begin
          level, status, desc = yield
        rescue StandardError => e
          level = :fatal
          status = :error
          desc = e.class
          error = e
        ensure
          @locked = false
        end
      end

      label = status || level

      return unless block_given? or @debug or level != :debug

      status_text = "[#{label}]"

      if desc.nil?
        @out.puts status_text.send(label)
      else
        @out.puts "#{status_text} - #{desc}".send(label)
      end

      raise error if error
    end

    private

    def indent
      ' ' * (@level * @indent)
    end

    def write message, fill: false, color: nil
      output = if message.nil? or message.empty?
                 indent
               else
                 message.lines.map do |line|
                   indent + line
                 end.join
               end

      output += '.' * (@width > output.length ? @width - output.length : 0) if fill
      output = output.send(color) unless color.nil?

      @out.print output
    end
  end

  class SimpleReporter
    def initialize config
      @out = config['stdout'] || $stdout
      @debug = config['debug']
    end

    def report runs
      runs = runs.select { |x| x.parent.is_a? Specification }

      errors    = runs.count { |x| x.status == :error }
      failed    = runs.count { |x| x.status == :failed }
      skipped   = runs.count { |x| x.status == :skipped }
      succeeded = runs.count - errors - failed - skipped

      summary  = "#{succeeded} succeeded"
      summary += " #{failed} failures"
      summary += " #{errors} errors"
      summary += " #{skipped} skipped"

      @out.puts(summary.send((errors + failed).positive? ? :red : :green))

      output = "\n"

      runs
        .select { |x| [:error, :failed].include? x.status }
        .each_with_index do |run, index|
          index += 1

          output += "#{index})"
          output += " #{run.parent.full_desc}"
          output += " (#{run.finished - run.started})"
          output += " [#{run.parent.name}]"

          output += "\n"

          if run.error
            file, line = get_call_location(run.error.backtrace_locations)

            error_output  = "but an unexpected error occurred during run\n"
            error_output += "  file.....: #{file}:#{line}\n" if file
            error_output += "  type.....: #{run.error.class.name}\n"
            error_output += "  message..: #{run.error.message}\n"

            if @debug and run.error.backtrace
              error_output += "  backtrace:\n"

              run.error.backtrace.each do |trace|
                error_output += "    #{trace}\n"
              end
            end

            output += error_output.indent(5)
            output += "\n\n"
          end

          next unless run.status == :failed

          failed = run.evaluations
            .select { |x| x.failures.any? }

          failed.each_with_index do |eval, eval_idx|
            output += if failed.count == 1
                        "     #{eval.desc}, but"
                      else
                        "     #{index}.#{eval_idx + 1}) #{eval.desc}, but"
                      end

            if eval.failures.count == 1
              output += " #{eval.failures.first.message}\n"
            else
              output += " #{eval.failures.count} failures occured\n"

              eval.failures.each_with_index do |fail, fail_idx|
                output += if failed.count == 1
                            "       #{index}.#{fail_idx + 1}) #{fail.message}\n"
                          else
                            "       #{index}.#{eval_idx + 1}.#{fail_idx + 1}) #{fail.message}\n"
                          end
              end
            end
          end

          output += "\n"
        end

      @out.puts output.red
    end
  end

  class JsonFormatter
    def initialize config
      @out = config['stdout'] || $stdout
      @out.sync = true
      @curr_scope = nil
    end

    def describe contexts
      @out.puts JSON.dump de(contexts)
    end

    def de contexts
      contexts.map do |context|
        {
          name: context.name,
          desc: context.desc,
          specs: context.specs.map do |spec|
            {
              name: spec.name,
              desc: spec.desc,
              tags: spec.tags,
              file: spec.file,
              data: spec.data,
            }
          end,
          children: de(context.children),
        }
      end
    end

    def list specs
      @out.puts JSON.pretty_generate(specs.map do |spec|
        {
          name: spec.name,
          desc: spec.desc,
          tags: spec.tags,
          file: spec.file,
          data: spec.data,
        }
      end)
    end

    def collections engine
      @out.puts(engine.collections.map do |name, config|
        {
          name:,
          config:,
          specs: engine.list(config).map(&:name),
        }
      end.to_json)
    end

    def environment env
      @out.puts env.to_json
    end

    def scope desc, type
      id = SecureRandom.hex(8)

      prev_scope = @curr_scope

      if type.is_a?(Specification)
        spec = type.name
        type = :spec
      end

      if type.is_a?(DefinitionContext)
        context = type.name
        type = :context
      end

      @out.puts JSON.dump({
        id: id,
        type: 'scope',
        desc: desc,
        parent: @curr_scope,
        scope: type,
        spec: spec,
        context: context,
      })

      @curr_scope = id
      yield
    ensure
      @curr_scope = prev_scope
    end

    def log level, message, status = nil, desc = nil
      id = SecureRandom.hex(8)

      @out.puts JSON.dump({
        id: id,
        parent: @curr_scope,
        type: 'log',
        level: level,
        message: message,
        status: status,
        desc: desc,
      })

      return unless block_given?

      begin
        level, status, desc = yield
      rescue StandardError => e
        level = :fatal
        status = :error
        desc = e.class
        error = e
      end

      @out.puts JSON.dump({
        id: id,
        type: 'status',
        level: level,
        status: status,
        desc: desc,
        error: error,
      })
    end
  end

  class JsonReporter
    def initialize config
      @out = config['stdout'] || $stdout
      @debug = config['debug']
    end

    def report runs
      runs = runs.select { |x| x.parent.is_a? Specification }

      errors    = runs.count { |x| x.status == :error }
      failed    = runs.count { |x| x.status == :failed }
      skipped   = runs.count { |x| x.status == :skipped }
      succeeded = runs.count - errors - failed - skipped

      report = {
        errors: errors,
        failed: failed,
        skipped: skipped,
        succeeded: succeeded,
        runs: runs.map do |run|
          {
            spec: run.parent.name,
            desc: run.parent.full_desc,
            duration: run.finished - run.started,
            status: run.status,
            logs: run.logs,
            error: run.error,
            evaluations: run.evaluations.map do |evaluation|
              {
                desc: evaluation.desc,
                failures: evaluation.failures.map do |failure|
                  {
                    message: failure.message,
                    file: failure.file,
                    line: failure.line,
                  }
                end
              }
            end
          }
        end
      }

      @out.puts JSON.dump(report)
    end
  end

  class Mixin
    include Delegate

    # The description of the mixin. This value has to be unique
    # as it is used for running the mixin.
    attr_reader :desc
    # A list of required parameters the mixin uses.
    # When running the mixin, given params must contain the keys in this list.
    attr_reader :params
    # The file where the mixin is defined
    attr_reader :file
    # The line in the file where the mixin is defined
    attr_reader :line

    def initialize desc, required, block, file, line
      @desc = desc
      @params = required
      @block = block
      @file = file
      @line = line
      @given = {}
    end

    ##
    # Add execution paramters. Available within the block
    # of a mixin execution.
    #
    #   run 'some mixin' do
    #     with some_key: 'a value',
    #          a_number: 42
    #   end
    #
    def with **params
      @given.merge! params
    end

    ##
    # Run the mixin with the given parameters in the context of the given +RunContext+
    # All methods of the +RunContext+ are available within the mixin block
    #
    def run run_context, params
      params ||= {}

      case params
      when Hash
        params.merge! @given unless @given.empty?

        if @params.any?
          missing_params = @params - params.keys
          raise "missing params: #{missing_params.join(', ')}" unless missing_params.empty?
        end

        params = [params.to_recursive_struct]
      when Array
        params = params.map(&:to_recursive_struct)
      end

      run_context.instance_exec(*params, &@block)
    end
  end

  class RunContext
    include Delegate

    attr_reader :name, :parent, :type, :logs, :bag, :error,
                :evaluations, :started, :finished, :properties, :data

    ##
    # The default identifier of +async+ blocks.
    #
    DEFAULT_ASYNC_NAME = 'default'

    @@current = nil
    @@location_cache = {}
    @@skip_count = 0

    ##
    # The current executing +RunContext+
    #
    def self.current
      @@current
    end

    def initialize engine, parent, type, bag = nil
      @engine = engine
      @parent = parent
      @type = type
      @logs = []

      @threads = {}

      @name = parent.name
      @name += "-#{type}" unless type == :spec

      @bag = OpenStruct.new(bag)

      @properties = {}

      @evaluations = []
      @error = nil
      @skipped = false

      @started = Time.now

      begin
        @@current = self
        yield self
      ensure
        @finished = Time.now
        @@current = nil
      end
    end

    ##
    # Executes the given block in the context of this +RunContext+.
    # For internal use only. Do not execute within an +it+ block.
    #
    def execute(data, &)
      @data = data
      instance_exec(data.is_a?(Hash) ? OpenStruct.new(data) : data, &)
    rescue AbortException
      # Do nothing. The run will be ended here
    rescue Interrupt
      @skipped = true
      @engine.formatter.log(:debug, nil, :skipped, 'canceled by user')
      @engine.logger.info("#{@parent.desc} - canceled by user")
      raise Interrupt if (@@skip_count += 1) > 2
    rescue StandardError => e
      @error = e
      @engine.formatter.log(:fatal, e.message, :error, e.class.name)
      @engine.logger.fatal("#{e.message}\n#{e.backtrace.join("\n")}")
    end

    ##
    # The status of the current run.
    # One of +:error+, +:failed+, +:skipped+ or +:success+
    #
    def status
      return :error if @error
      return :failed if @evaluations.any? { |x| x.failures.any? }
      return :skipped if @skipped

      :success
    end

    ##
    # :method: debug
    # :args: message
    #
    # Logs a debug message. Only when +debug+ config option is set to +true+.
    #

    ##
    # :method: info
    # :args: message
    #
    # Logs a info message.
    #

    ##
    # :method: warn
    # :args: message
    #
    # Logs a warn message.
    #

    %i[debug info warn].each do |method|
      define_method(method) do |message|
        message = message.to_s
        @engine.logger.send(method, message)
        @engine.formatter.log(method, message)
      end
    end

    alias log info

    ##
    # Access the loaded resources (files)
    #
    def resources
      @engine.resources
    end

    ##
    # Raise a failure error.
    # Using this method within an +assert+ or +expect+ block
    # will report an error.
    #
    def fail_with message
      raise Failure, message
    end

    ##
    # :method: assert
    # :args: desc
    #
    # Assert a specific condition. If a block is given methods from
    # the +EvaluationContext+ are available. If a failure is reported
    # within this block, the run will be *aborted*.

    ##
    # :method: expect
    # :args: desc
    #
    # Expect a specific condition. If a block is given methods from
    # the +EvaluationContext+ are available. If a failure is reported
    # within this block, the run will *continue*.
    #
    %i[assert expect].each do |method|
      define_method(method) do |evaluation, &block|
        desc = "#{method} #{evaluation}"

        @evaluations << if block
                          EvaluationContext.new(@engine, desc, &block)
                        else
                          EvaluationContext.new(@engine, desc) do
                            unless evaluation.failure.nil?
                              @failures << Failure.new(
                                evaluation.failure,
                                evaluation.call_location
                              )
                            end
                          end
                        end

        raise AbortException if method == :assert and @evaluations.any? { |x| x.failures.any? }
      end
    end

    ##
    # Adds the given key-value arguments to the run report.
    # Use this to add generated values during the run to the test report.
    #
    #   property key: 'value'
    #
    def property **kwargs
      @properties.merge!(kwargs)
    end

    ##
    # Takes a block and measures the time of the execution.
    # The duration in seconds is available through +duration+.
    #
    #   measure do
    #     info 'do some long running stuff'
    #     sleep 1
    #   end
    #
    #   info "run duration was #{duration}"
    #
    def measure
      start_time = Time.now
      yield
      end_time = Time.now

      @measured_duration = end_time - start_time
    end

    ##
    # returns::
    #   The duration of the previously executed +measure+ block.
    #
    # The duration optained by +measure+.
    #
    def duration
      @measured_duration
    end

    ##
    # Executes the given block asyncronously in a new thread.
    # This thread can be awaited with +await+ and the given name.
    # You can start multiple threads with the same name.
    # Using this name with +await+ will wait for all threads to finish.
    #
    # The last line in the +async+ block will be returned as a result.
    # and is available when +await+ ing the threads.
    #
    #   async do
    #     info 'do some async stuff'
    #
    #     'a result'
    #   end
    #
    #   result = await
    #
    def async(name = DEFAULT_ASYNC_NAME, &)
      @threads[name] ||= []
      @threads[name] << Thread.new(&)
    end

    ##
    # returns:: An +Array+ of previously executed +async+ blocks
    # with the same name.
    #
    # Waits for the threads created with +async+ to finish.
    # Awaits all threads with the given name.
    #
    def await name = DEFAULT_ASYNC_NAME
      return unless @threads.key? name

      threads = @threads[name].map(&:join)

      @threads.delete(name)

      threads.map(&:join)
    end

    ##
    # Groups code in a block.
    # This is solely used for structuring tests
    # and will not have effect on test reports.
    #
    def group(desc, &)
      @engine.logger.correlate do
        @engine.logger.debug("group \"#{desc}\"")
        @engine.formatter.scope(desc, :group, &)
      end
    end

    ##
    # Observes the given block and catches all errors
    # within this block. If errors or failures occur
    # the test will not fail or aborted.
    #
    # The result of the observation can be retreived
    # through +success?+
    #
    #   observe do
    #     info 'do some stuff'
    #   end
    #
    #   assert success?.to be true
    #
    #   observe do
    #     raise StandardError, 'Oops!'
    #   end
    #
    #   assert success?.to be false
    #
    def observe desc
      @engine.formatter.log(:info, "observe #{desc}") do
        yield
        @success = true
        [:info, :ok, nil]
      rescue StandardError => e
        @success = false
        @engine.logger.warn("#{e.message}\n#{e.backtrace.join("\n")}")
        [:info, :warn, e.message]
      end
    end

    ##
    # Returns the status of the pervious +observe+ block
    #
    def success?
      @success.nil? ? true : @success
    end

    ##
    # Run the mixin with the given name and parameters
    #
    #   run 'additional actions' do
    #     with some_param: 42,
    #          another_param: 'foo'
    #   end
    #
    def run(desc, with: nil, &)
      @engine.formatter.scope(desc, :mixin) do
        raise "mixin \"#{desc}\" not found" unless @engine.mixins.key? desc

        mixin = @engine.mixins[desc]
        mixin.instance_eval(&) if block_given?

        @engine.logger.correlate do
          @engine.logger.debug("execute mixin \"#{desc}\"")
          result = mixin.run(self, with)
          return result.is_a?(Hash) ? OpenStruct.new(result) : result
        end
      end
    end

    ##
    # Add this alias to construct prettier and more readable mixin execution calls
    #
    alias also run

    ##
    # Skip the run for this spec
    #
    def skip message
      @skipped = true
      @engine.logger.info("#{message} - canceled by user")
      raise AbortException
    end
  end

  class Specification
    attr_reader :id, :name, :desc, :full_desc, :parent, :root, :tags, :data, :file

    def initialize parent, name, desc, tags, data, file, block
      @parent = parent
      @root = parent.root
      @name = name
      @desc = desc
      @tags = tags
      @data = data
      @file = file
      @block = block
      @full_desc = "#{@parent.full_desc} #{@desc}"
    end

    ##
    # Creates a new +RunContext+ and executes the spec,
    # +before+ and +after+ blocks
    #
    def run engine, befores, afters, bag
      RunContext.new(engine, self, :spec, bag) do |run_context|
        engine.formatter.scope(@desc, self) do
          befores.each do |block|
            engine.formatter.scope('before', :before) do
              engine.logger.correlate do
                run_context.execute(@data, &block)
              end
            end
          end

          run_context.execute(@data, &@block) if run_context.status == :success
        ensure
          afters.each do |block|
            engine.formatter.scope('after', :after) do
              engine.logger.correlate do
                run_context.execute(@data, &block)
              end
            end
          end
        end
      end
    end
  end

  class DefinitionContext
    include Delegate

    attr_reader :id, :name, :desc, :parent, :full_desc, :children, :specs, :file

    def initialize desc, file, parent = nil
      @parent = parent
      @desc = desc
      @file = file
      @children = []
      @specs = []

      @setups = []
      @teardowns = []

      @befores = []
      @afters = []

      @name = @desc.downcase.gsub(/[^a-z0-9]+/, '_')
      @name = @parent.name + '-' + @name unless @parent.nil?

      @full_desc = @parent.nil? ? @desc : "#{@parent.full_desc} #{@desc}"
    end

    ##
    # The root context aka test subject.
    #
    def root
      @parent ? @parent.root : self
    end

    ##
    # A flattened list of all specs including those of child contexts.
    #
    def all_specs
      @specs + @children.map(&:all_specs).flatten
    end

    ##
    # Creates a new sub context with the given block.
    #
    def context(desc, &)
      file = caller
        .first
        .gsub(/:in .*/, '')
        .gsub(Dir.pwd, '.')

      context = DefinitionContext.new(desc, file, self)
      @children << context
      context.instance_eval(&)
    end

    ##
    # Adds a setup block which will be executed
    # once at the beginning of a context.
    # Multiple setups are allowed.
    #
    def setup &block
      @setups << block
    end

    ##
    # Adds a teardown block which will be executed
    # once at the end of a context.
    # Multiple teardowns are allowed.
    #
    def teardown &block
      @teardowns << block
    end

    ##
    # Creates a new block which will be executed *before*
    # each +it+ block.
    #
    def before &block
      @befores << block
    end

    ##
    # Creates a new block which will be executed *after*
    # each +it+ block. These blocks are ensured to be executed,
    # even on failure or error.
    #
    def after &block
      @afters << block
    end

    ##
    # Creates a new specifiction (test). This is the main
    # building block of a spectre tests and contains all test logic.
    #
    def it desc, tags: [], with: nil, &block
      file = caller
        .first
        .gsub(/:in .*/, '')
        .gsub(Dir.pwd, '.')

      with ||= [nil]

      with.each_with_index do |data, _index|
        spec_index = root.all_specs.count + 1
        name = "#{root.name}-#{spec_index}"

        spec = Specification.new(self, name, desc, tags, data, file, block)

        @specs << spec
      end
    end

    def run engine, specs
      runs = []

      return runs unless all_specs.any? { |x| specs.include? x }

      selected = @specs.select { |x| specs.include? x }

      engine.formatter.scope(@desc, self) do
        if selected.any?
          setup_bag = nil

          if @setups.any?
            setup_run = RunContext.new(engine, self, :setup) do |run_context|
              @setups.each do |block|
                engine.formatter.scope('setup', :setup) do
                  engine.logger.correlate do
                    engine.logger.debug("setup \"#{@desc}\"")
                    run_context.execute(nil, &block)
                  end
                end
              end
            end

            setup_bag = setup_run.bag

            runs << setup_run
          end

          # Only run specs if setup was successful
          if runs.all? { |x| x.status == :success }
            runs += selected.map do |spec|
              engine.logger.correlate do
                spec.run(engine, @befores, @afters, setup_bag)
              end
            end
          end

          if @teardowns.any?
            runs << RunContext.new(engine, self, :teardown, setup_bag) do |run_context|
              @teardowns.each do |block|
                engine.formatter.scope('teardown', :teardown) do
                  engine.logger.correlate do
                    engine.logger.debug("teardown \"#{@desc}\"")
                    run_context.execute(nil, &block)
                  end
                end
              end
            end
          end
        end

        @children.each do |context|
          engine.logger.correlate do
            runs += context.run(engine, specs)
          end
        end
      end

      runs
    end
  end

  ##
  # Defines the default config.
  #
  CONFIG = {
    'work_dir' => '.',
    'global_config_file' => '~/.config/spectre.yml',
    'config_file' => 'spectre.yml',
    'log_file' => nil, # Deactivate logging by default
    'log_date_format' => '%F %T.%L%:z',
    # Format: [timestamp] LEVEL -- module_name: [spec-id] correlation_id log_message
    'log_message_format' => "[%s] %5s -- %s: [%s] [%s] %s\n",
    'formatter' => 'Spectre::SimpleFormatter',
    'reporters' => ['Spectre::SimpleReporter'],
    'out_path' => 'reports',
    'specs' => [],
    'tags' => [],
    'debug' => false,
    'env_patterns' => ['environments/**/*.env.yml'],
    'env_partial_patterns' => ['environments/**/*.env.secret.yml'],
    'spec_patterns' => ['specs/**/*.spec.rb'],
    'mixin_patterns' => ['mixins/**/*.mixin.rb'],
    'collections_patterns' => ['**/*.collections.yml'],
    'resource_paths' => ['../common/resources', './resources'],
    'modules' => [],
  }

  ##
  # The default environment name, when not set in `env` file
  # or as selected `env`
  #
  DEFAULT_ENV_NAME = 'default'

  class Engine
    attr_reader :env, :formatter, :config, :contexts, :mixins, :collections, :resources

    @@current = nil
    @@modules = []

    ##
    # The current used engine
    #
    def self.current
      @@current
    end

    ##
    # Register a class and methods, which should be
    # available in all spectre scopes
    #
    def self.register cls, *methods
      @@modules << [cls, methods]
    end

    def initialize config
      @environments = {}
      @collections = {}
      @contexts = []
      @mixins = {}
      @resources = {}
      @delegates = {}

      @config = Marshal.load(Marshal.dump(CONFIG))

      # Load global config file
      global_config_file = config['global_config_file'] || File.expand_path('~/.config/spectre.yml')

      if File.exist? global_config_file
        global_config = load_yaml(global_config_file)
        @config.deep_merge!(global_config)
      end

      # Set working directory so all paths in config
      # are relative to this directory
      Dir.chdir(config['work_dir'] || @config['work_dir'] || '.')

      # Load main spectre config
      main_config_file = config['config_file'] || @config['config_file']

      unless main_config_file.nil? or !File.exist? main_config_file
        main_config = load_yaml(main_config_file)
        @config.deep_merge!(main_config)
        Dir.chdir(File.dirname(main_config_file))
      end

      # Load environments
      @config['env_patterns'].each do |pattern|
        Dir.glob(pattern).each do |file_path|
          loaded_env = load_yaml(file_path)
          env_name = loaded_env['name'] || DEFAULT_ENV_NAME
          @environments[env_name] = loaded_env
        end
      end

      # Load and merge partial environment files
      @config['env_partial_patterns'].each do |pattern|
        Dir.glob(pattern).each do |file_path|
          loaded_env = load_yaml(file_path)
          env_name = loaded_env['name'] || DEFAULT_ENV_NAME
          @environments[env_name].deep_merge!(loaded_env) if @environments.key?(env_name)
        end
      end

      # Select environment and merge it
      @config.deep_merge!(@environments[config.delete('selected_env') || DEFAULT_ENV_NAME])

      # Load collections
      @config['collections_patterns'].each do |pattern|
        Dir.glob(pattern).each do |file_path|
          @collections.merge! load_yaml(file_path)
        end
      end

      # Use collection if given
      if config.key? 'collection'
        collection = @collections[config['collection']]

        raise "collection #{config['collection']} not found" unless collection

        @config.deep_merge!(collection)
      end

      # Merge property overrides
      @config.deep_merge!(config)

      # Set env before loading specs in order to make it available in spec definitions
      @env = @config.to_recursive_struct

      # Load specs
      # Note that spec files are only loaded once, because of the relative require,
      # even if the setup function is called multiple times
      load_files(@config['spec_patterns'])

      # Load mixins
      # Mixins are also only loaded once
      load_files(@config['mixin_patterns'])

      # Load resources
      @config['resource_paths'].each do |resource_path|
        resource_files = Dir.glob File.join(resource_path, '**/*')

        resource_files.each do |file|
          file.slice! resource_path
          file = file[1..]
          @resources[file] = File.expand_path File.join(resource_path, file)
        end
      end

      @formatter = Object
        .const_get(@config['formatter'])
        .new(@config)

      # Load modules
      return unless @config['modules'].is_a? Array

      @config['modules'].each do |module_name|
        module_path = File.join(Dir.pwd, module_name)

        if File.exist? module_path
          require_relative module_path
        else
          require module_name
        end
      end
    end

    # :nodoc:
    def respond_to_missing?(method, *)
      @delegates.key? method
    end

    # :nodoc:
    def method_missing(method, *, **, &)
      @delegates[method]&.send(method, *, **, &)
    end

    # :nodoc:
    def logger
      @logger ||= Logger.new(@config, progname: 'spectre')
    end

    ##
    # Get a list of specs with the configured filter
    #
    def list config = @config
      spec_filter = config['specs'] || []
      tag_filter = config['tags'] || []

      @contexts
        .map(&:all_specs)
        .flatten
        .select do |spec|
          (spec_filter.empty? and tag_filter.empty?) or
            spec_filter.any? { |x| spec.name.match?("^#{x.gsub('*', '.*')}$") } or
            tag_filter.any? { |x| tag?(spec.tags, x) }
        end
    end

    ##
    # Runs specs with the current config
    #
    def run
      @@modules.each do |mod, methods|
        target = mod.respond_to?(:new) ? mod.new(@config, logger) : mod

        methods.each do |method|
          @delegates[method] = target
        end
      end

      list
        .group_by { |x| x.parent.root }
        .map do |context, specs|
          context.run(self, specs)
        end
        .flatten
    rescue Interrupt
      # Do nothing here
    end

    ##
    # Create a report with the given runs and configured reporter.
    #
    def report runs
      @config['reporters'].each do |reporter|
        Object.const_get(reporter)
          .new(@config)
          .report(runs)
      end
    end

    ##
    # Cleanup temporary files like logs, etc.
    #
    def cleanup
      Dir.chdir(@config['work_dir'])
      log_file_pattern = @config['log_file'].gsub('<date>', '*')
      FileUtils.rm_rf(Dir.glob(log_file_pattern), secure: true)
    end

    ##
    # Describe a test subject
    #
    def describe(name, &)
      file = caller
        .first
        .gsub(/:in .*/, '')
        .gsub(Dir.pwd, '.')

      main_context = @contexts.find { |x| x.desc == name }

      if main_context.nil?
        main_context = DefinitionContext.new(name, file)
        @contexts << main_context
      end

      main_context.instance_eval(&)
    end

    ##
    # Registers a mixin
    #
    def mixin desc, params: [], &block
      file, line = get_call_location(caller_locations)
      @mixins[desc] = Mixin.new(desc, params, block, file, line)
    end

    private

    def load_files patterns
      @@current = self

      patterns.each do |pattern|
        Dir.glob(pattern).each do |file|
          content = File.read File.join(Dir.pwd, file)
          instance_eval(content, file, 1)
        end
      end

      @@current = nil
    end

    def load_yaml file_path
      YAML.safe_load_file(file_path, aliases: true) || {}
    end

    def tag? tags, tag_exp
      tags = tags.map(&:to_s)
      all_tags = tag_exp.split('+')

      included_tags = all_tags.reject { |x| x.start_with? '!' }

      excluded_tags = all_tags
        .select { |x| x.start_with? '!' }
        .map { |x| x[1..] }

      included_tags & tags == included_tags and excluded_tags & tags == []
    end
  end

  # Delegate methods to specific classes or instances
  # to be available in descending block
  [
    [Assertion, :be, :be_empty, :contain, :match],
    [Helpers, :uuid, :now],
  ].each do |args|
    Engine.register(*args)
  end
end
