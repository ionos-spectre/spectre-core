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
        .map { |key, val| [key, val.deep_freeze] }
        .to_h
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
    def initialize extensions
      @extensions = extensions
    end

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
      elsif @extensions.key? method
        @extensions[method].send(method, *args, **kwargs, &block)
      else
        raise "no method or variable `#{method}' defined"
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

  ###########################################
  # DSL Classes
  ###########################################

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

    def self.scope(*method, target)
      delegate(*methods, target)
      yield
      remove(*methods)
    end

    private

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

    def self.remove(*methods)
      methods.each do |method_name|
        remove_method(method_name)
        @@mappings.delete(method_name)
      end
    end
  end

  class Eventing
    def initialize
      @handlers = []
    end

    def trigger event, *args
      if block_given?
        broadcast('start_' + event.to_s, *args)

        begin
          yield
        ensure
          broadcast('end_' + event.to_s, *args)
        end
      else
        broadcast(event, *args)
      end
    end

    def register handler
      @handlers << handler
    end

    private

    def broadcast event, *args
      @handlers.each do |handler|
        handler.send(event, *args) if handler.respond_to? event
      end
    end
  end

  class SpectreScope
    @@modules = {}
    @@semaphore = Mutex.new

    attr_reader :subjects, :env, :bag, :eventing, :logger, :extensions

    def initialize
      @subjects = []
      @extensions = {}
      @env = OpenStruct.new
      @bag = OpenStruct.new
      @eventing = Eventing.new
      @logger = Logging::SpectreLogger.new('spectre')
    end

    def describe desc, &block
      subject = @subjects.find { |x| x.desc == desc }

      unless subject
        subject = Subject.new(desc)
        @subjects << subject
      end

      ctx = SpecContext.new(subject)
      ctx._evaluate &block
    end

    def specs spec_filter=[], tags=[]
      @subjects
        .map { |x| x.specs }
        .flatten
        .select do |spec|
          (spec_filter.empty? or spec_filter.any? { |x| spec.name.match('^' + x.gsub('*', '.*') + '$') }) or (tags.empty? or tags.any? { |x| tag?(spec.tags, x) })
        end
    end

    def load patterns, working_dir
      @@semaphore.synchronize do
        Delegator.scope(:describe, :env, self) do

          patterns.each do |pattern|
            pattern = File.join(working_dir, pattern)

            Dir.glob(pattern).each do|spec_file|
              Kernel.load spec_file
            end
          end

        end
      end
    end

    def configure config, modules
      @env = to_recursive_ostruct(config)

      @extensions[:env] = self

      modules.each do |mod|
        next unless @@modules.key? mod

        mod_logger = Logging::SpectreLogger.new(mod)

        mod_instance = @@modules[mod].call(mod_logger, config)

        mod_instance
          .public_methods(false)
          .each do |method_name|
            @extensions[method_name] = mod_instance
          end
      end
    end

    def run specs
      Runner.new(self).run(specs)
    end

    def self.register name, &block
      @@modules[name] = block
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