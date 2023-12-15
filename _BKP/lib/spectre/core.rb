require_relative 'environment'
require_relative 'logging'

module Spectre
  class ::Hash
    def deep_merge!(second)
      merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge!(v2, &merger) : v2 }
      self.merge!(second, &merger)
    end

    def deep_merge(second)
      self.deep_clone.deep_merge!(second.deep_clone)
    end

    def deep_freeze
      self
        .to_h { |key, val| [key, val.deep_freeze] }
        .freeze
    end

    def to_recursive_struct
      OpenStruct.new(
        self.each_with_object({}) do |(key, val), memo|
          memo[key] = val.is_a?(Hash) ? val.to_recursive_struct : val
        end
      )
    end
  end

  class ::Array
    def deep_freeze
      self.map { |x| x.deep_freeze }
    end
  end

  class ::Object
    def to_h
      self.instance_variables.each_with_object({}) do |var, hash|
        hash[var.to_s.delete("@")] = self.instance_variable_get(var)
      end
    end

    def deep_freeze
      self.freeze
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

  ###########################################
  # Internal Classes
  ###########################################

  # https://www.dan-manges.com/blog/ruby-dsls-instance-eval-with-delegation
  class DslBase
    def _evaluate &block
      @__bound_self__ = eval('self', block.binding)
      instance_eval(&block)
    end

    def _execute *args, &block
      @__bound_self__ = eval('self', block.binding)
      instance_exec(*args, &block)
    end

    def method_missing(method, *args, **kwargs, &)
      @__bound_self__.send(method, *args, **kwargs, &)
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
        specs: @specs.map { |x| x.to_h },
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

  ###########################################
  # DSL Contexts
  ###########################################

  class SpectreContext
    attr_reader :env

    def initialize scope
      @scope = scope
    end

    def env
      @scope.env
    end

    def describe(desc, &)
      subject = @scope.subjects.find { |x| x.desc == desc }

      unless subject
        subject = Subject.new(desc)
        @scope.subjects << subject
      end

      ctx = SpecContext.new(subject)
      ctx._evaluate(&)
    end
  end

  class SpecContext < DslBase
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

    def context(desc=nil, &)
      ctx = SpecContext.new(@__subject, desc, self)
      ctx._evaluate(&)
    end

    private

    def get_call_location
      path_and_line = caller[1].split(':')
      line = path_and_line[-2].to_i
      file = path_and_line[0..-3].join(':')
      [file, line]
    end
  end

  class ModuleContext
    def initialize scope
      @scope = scope
    end

    def register *methods, &factory
      methods.each do |_method_name|
        @scope.extensions << [*methods, factory]
      end
    end
  end

  ###########################################
  # Core Modules
  ###########################################

  class Eventing
    def initialize scope
      @scope = scope
      @handlers = []
    end

    def trigger event, *args, run_info: nil
      if block_given?
        broadcast('start_' + event.to_s, *args, run_info: run_info)

        begin
          yield
        ensure
          broadcast('end_' + event.to_s, *args, run_info: run_info)
        end
      else
        broadcast(event, *args, run_info: run_info)
      end
    end

    def register handler
      @handlers << handler
    end

    private

    def broadcast event, *args, run_info: nil
      @handlers.each do |handler|
        handler.send(event, *args, run_info: run_info) if handler.respond_to? event
      end

      run_info.events << [event, *args] if run_info
    end
  end

  class SpectreScope
    attr_reader :subjects, :vars, :runs, :env, :bag, :event, :log, :logger, :extensions

    @@modules = {}

    def self.define name, &block
      @@modules[name] = block
    end

    def initialize
      @subjects = []
      @extensions = []
      @vars = {}
      @env = OpenStruct.new
      @bag = OpenStruct.new
      @event = Eventing.new(self)
      @log = Logging::SpectreLogger.new(self)
      @loggers = {}
      @runs = []

      @logger = @log.create_logger('spectre')
    end

    def specs spec_filter=[], tags=[]
      @subjects
        .map { |x| x.specs }
        .flatten
        .select do |spec|
          (spec_filter.empty? and tags.empty?) or (spec_filter.any? { |x| spec.name.match?('^' + x.gsub('*', '.*') + '$') }) or (tags.any? { |x| tag?(spec.tags, x) })
        end
    end

    def load_specs patterns, working_dir
      spectre_ctx = SpectreContext.new(self)

      patterns.each do |pattern|
        pattern = File.join(working_dir, pattern)

        Dir.glob(pattern).each do |spec_file|
          spectre_ctx.instance_eval(File.read(spec_file), spec_file, 1)
        end
      end

      self
    end

    def configure config
      @env = to_recursive_ostruct(config)

      mod_ctx = ModuleContext.new(self)

      @@modules.each do |mod_name, define_block|
        logger = @log.create_logger(mod_name)
        mod_ctx.instance_exec(config, logger, self, &define_block)
      end

      self
    end

    private

    def tag? tags, tag_exp
      tags = tags.map { |x| x.to_s }
      all_tags = tag_exp.split('+')
      included_tags = all_tags.select { |x| !x.start_with? '!' }
      excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
      included_tags & tags == included_tags and excluded_tags & tags == []
    end

    def to_recursive_ostruct(hash)
      OpenStruct.new(
        hash.each_with_object({}) do |(key, val), memo|
          memo[key] = val.is_a?(Hash) ? to_recursive_ostruct(val) : val
        end
      )
    end
  end
end
