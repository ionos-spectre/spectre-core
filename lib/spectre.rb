module Spectre
  module Version
    MAJOR = 1
    MINOR = 14
    TINY  = 2
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'


  class ::Hash
    def deep_merge!(second)
      merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge!(v2, &merger) : v2 }
      self.merge!(second, &merger)
    end
  end

  class ::Object
    def to_h
      self.instance_variables.each_with_object({}) do |var, hash|
        hash[var.to_s.delete("@")] = self.instance_variable_get(var)
      end
    end

    def deep_clone
      Marshal.load(Marshal.dump(self))
    end
  end


  ###########################################
  # Custom Exceptions
  ###########################################


  class SpectreError < Exception
  end

  class ExpectationFailure < Exception
    attr_reader :expectation

    def initialize message, expectation
      super message
      @expectation = expectation
    end
  end

  class SpectreSkip < Interrupt
  end

  ###########################################
  # Internal Modules
  ###########################################

  module Event
    @@handlers = []

    def self.send event, *args
      @@handlers.each do |handler|
        handler.send(event, *args) if handler.respond_to? event
      end
    end

    def self.register handler
      @@handlers << handler
    end
  end

  ###########################################
  # Internal Classes
  ###########################################


  # https://www.dan-manges.com/blog/ruby-dsls-instance-eval-with-delegation
  class DslClass
    def _evaluate &block
      @__bound_self__ = eval('self', block.binding)
      instance_eval(&block)
    end

    def _execute *args, &block
      @__bound_self__ = eval('self', block.binding)
      instance_exec(*args, &block)
    end

    def method_missing method, *args, **kwargs, &block
      if @__bound_self__.respond_to? method
        @__bound_self__.send(method, *args, **kwargs, &block)
      else
        Delegator.redirect(method, *args, **kwargs, &block)
      end
    end
  end

  class Subject
    attr_reader :name, :desc, :specs

    def initialize desc
      @desc = desc
      @specs = []
      @name = desc.downcase.gsub(/[^a-z0-9]+/, '_')
    end

    def add_spec desc, tags, data, block, context, file, line
      name = @name + '-' + (@specs.length+1).to_s
      @specs << Spec.new(name, self, desc, tags, data, block, context, file, line)
    end

    def to_h
      {
        name: @name,
        desc: @desc,
        specs: @specs.map { |x| x.to_h }
      }
    end
  end

  class Spec
    attr_reader :id, :name, :subject, :context, :desc, :tags, :data, :block, :file, :line

    def initialize name, subject, desc, tags, data, block, context, file, line
      @name = name
      @context = context
      @data = data
      @subject = subject
      @desc = desc
      @tags = tags
      @block = block
      @file = file
      @line = line
    end

    def full_desc
      @subject.desc + ' ' + desc
    end

    def to_h
      {
        name: @name,
        context: @context.__desc,
        data: @data.map { |x| x.to_h },
        subject: @subject.desc,
        desc: @desc,
        tags: @tags,
        file: @file,
        line: @line,
      }
    end
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
    def self.current
      Thread.current.thread_variable_get('current_run')
    end

    def self.current= run
      Thread.current.thread_variable_set('current_run', run)
    end

    def run specs
      runs = []

      specs.group_by { |x| x.subject }.each do |subject, subject_specs|
        Spectre::Event.send(:start_subject, subject)

        subject_specs.group_by { |x| x.context }.each do |context, context_specs|
          Spectre::Event.send(:start_context, context)
          runs.concat run_context(context, context_specs)
          Spectre::Event.send(:end_context, context)
        end

        Spectre::Event.send(:end_subject, subject)
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

      Spectre::Event.send(('start_' + type.to_s).to_sym, run_info)

      begin
        spec.block.call()

        run_info.finished = Time.now
      rescue ExpectationFailure => e
        run_info.failure = e
      rescue Exception => e
        run_info.error = e
        Spectre::Logging.log_error(spec, e)
      end

      run_info.finished = Time.now

      Spectre::Event.send(('end_' + type.to_s).to_sym, run_info)

      Runner.current = nil

      run_info
    end

    def run_spec spec, data=nil
      run_info = RunInfo.new(spec, data)

      Runner.current = run_info

      run_info.started = Time.now

      Event.send(:start_spec, run_info)

      begin
        if spec.context.__before_blocks.count > 0
          Event.send(:start_before, run_info)

          spec.context.__before_blocks.each do |block|
            block.call(data)
          end

          Event.send(:end_before, run_info)
        end

        spec.block.call(data)
      rescue ExpectationFailure => e
        run_info.failure = e
      rescue SpectreSkip => e
        run_info.skipped = true
        Event.send(:spec_skip, run_info, e.message)
      rescue Interrupt
        run_info.skipped = true
        Event.send(:spec_skip, run_info, 'canceled by user')
      rescue Exception => e
        run_info.error = e
        Event.send(:spec_error, run_info, e)
      ensure
        if spec.context.__after_blocks.count > 0
          Event.send(:start_after, run_info)

          begin
            spec.context.__after_blocks.each do |block|
              block.call
            end

            run_info.finished = Time.now
          rescue ExpectationFailure => e
            run_info.failure = e
          rescue Exception => e
            run_info.error = e
            Event.send(:spec_error, run_info, e)
          end

          Event.send(:end_after, run_info)
        end
      end

      run_info.finished = Time.now

      Event.send(:end_spec, run_info)

      Runner.current = nil

      run_info
    end
  end


  ###########################################
  # DSL Classes
  ###########################################


  class SpecContext < DslClass
    attr_reader :__subject, :__desc, :__parent, :__before_blocks, :__after_blocks, :__setup_blocks, :__teardown_blocks

    def initialize subject, desc=nil, parent=nil
      @__subject = subject
      @__desc = desc
      @__parent = parent

      @__before_blocks = []
      @__after_blocks = []
      @__setup_blocks = []
      @__teardown_blocks = []
    end

    def it desc, tags: [], with: [], &block
      spec_file, line = get_call_location()

      @__subject.add_spec(desc, tags, with, block, self, spec_file, line)
    end

    def before &block
      @__before_blocks << block
    end

    def after &block
      @__after_blocks << block
    end

    def setup &block
      name = "#{@__subject.name}-setup-#{@__setup_blocks.count+1}"
      spec_file, line = get_call_location()

      setup_ctx = SpecContext.new(@__subject, 'setup', self)
      @__setup_blocks << Spec.new(name, @__subject, 'setup', [], nil, block, setup_ctx, spec_file, line)
    end

    def teardown &block
      name = "#{@__subject.name}-teardown-#{@__teardown_blocks.count+1}"
      spec_file, line = get_call_location()

      teardown_ctx = SpecContext.new(@__subject, 'teardown', self)
      @__teardown_blocks << Spec.new(name, @__subject, 'teardown', [], nil, block, teardown_ctx, spec_file, line)
    end

    def context desc=nil, &block
      ctx = SpecContext.new(@__subject, desc, self)
      ctx._evaluate &block
    end

    private

    def get_call_location
      path_and_line = caller[1].split(':')
      line = path_and_line[-2].to_i
      file = path_and_line[0..-3].join(':')
      [file, line]
    end
  end


  ###########################################
  # Core Modules
  ###########################################


  module Delegator
    @@mappings = {}

    def self.delegate(*methods, target)
      methods.each do |method_name|
        define_method(method_name) do |*args, &block|
          return super(*args, &block) if respond_to? method_name

          target.send(method_name, *args, &block)
        end

        @@mappings[method_name] = target

        private method_name
      end
    end

    def self.redirect method_name, *args, **kwargs, &block
      target = @@mappings[method_name] || Kernel
      raise SpectreError.new("no variable or method '#{method_name}' found") unless target.respond_to? method_name

      target.send(method_name, *args, **kwargs, &block)
    end
  end


  class << self
    @@subjects = []
    @@modules = []

    def subjects
      @@subjects
    end

    def specs spec_filter=[], tags=[]
      @@subjects
        .map { |x| x.specs }
        .flatten
        .select do |spec|
          (spec_filter.empty? or spec_filter.any? { |x| spec.name.match('^' + x.gsub('*', '.*') + '$') }) and (tags.empty? or tags.any? { |x| tag?(spec.tags, x) })
        end
    end

    def tag? tags, tag_exp
      tags = tags.map { |x| x.to_s }
      all_tags = tag_exp.split('+')
      included_tags = all_tags.select { |x| !x.start_with? '!' }
      excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
      included_tags & tags == included_tags and excluded_tags & tags == []
    end

    def delegate *method_names, to: nil
      Spectre::Delegator.delegate(*method_names, to)
    end

    def register &block
      @@modules << block
    end

    def configure config
      @@modules.each do |block|
        block.call(config)
      end
    end

    def purge
      @@subjects = []
      @@modules = []
    end


    ###########################################
    # Global Functions
    ###########################################


    def describe desc, &block
      subject = @@subjects.find { |x| x.desc == desc }

      unless subject
        subject = Subject.new(desc)
        @@subjects << subject
      end

      ctx = SpecContext.new(subject)
      ctx._evaluate &block
    end

    def property key, val
      Spectre::Runner.current.properties[key] = val
    end

    def group desc
      Spectre::Event.send(:start_group, desc)
      yield
      Spectre::Event.send(:end_group, desc)
    end

    def skip message=nil
      raise SpectreSkip.new(message)
    end

    def info message
      Spectre::Event.send(:log, message, :info)
      Spectre::Runner.current.log << [DateTime.now, message, :info]
    end

    def debug message
      Spectre::Event.send(:log, message, :debug)
      Spectre::Runner.current.log << [DateTime.now, message, :debug]
    end

    alias :log :info
  end

  delegate(:describe, :property, :group, :skip, :log, :info, :debug, to: Spectre)
end


extend Spectre::Delegator
