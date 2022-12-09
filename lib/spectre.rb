require 'ostruct'

require_relative './spectre/environment'
require_relative './spectre/logging'

module Spectre
  module Version
    MAJOR = 2
    MINOR = 0
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'


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
      raise SpectreError.new("no variable or method `#{method_name}' found") unless target.respond_to? method_name

      target.send(method_name, *args, **kwargs, &block)
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
    attr_reader :subjects, :bag

    def initialize
      @subjects = []
      @modules = []
      @env = Environment.new
      @bag = OpenStruct.new
      @eventing = Eventing.new
      @logger = Logging::SpectreLogger.new('spectre')
    end

    def env
      @env
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

    def register mod
      @modules << mod
    end

    def load config
      Delegator.delegate(:describe, :env, self)

      if config.key? 'spec_patterns'
        config['spec_patterns'].each do |pattern|
          pattern = File.join(config['working_dir'] || Dir.pwd, pattern)

          Dir.glob(pattern).each do|spec_file|
            Kernel.load spec_file
          end
        end
      end
    end

    def configure config
      @logger.configure(config)

      @modules.each do |mod|
        mod.configure(config) if mod.respond_to? :configure
      end
    end

    def run specs, config={}
      load_modules(config)
      configure(config)

      Runner.new(@logger, @eventing, @bag).run(specs)
    end

    private

    def tag? tags, tag_exp
      tags = tags.map { |x| x.to_s }
      all_tags = tag_exp.split('+')
      included_tags = all_tags.select { |x| !x.start_with? '!' }
      excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
      included_tags & tags == included_tags and excluded_tags & tags == []
    end

    def load_modules config
      return unless config.key? 'modules'

      Spectre.scope self do
        config['modules']
          .concat(config['include'] || [])
          .select { |mod| !(config['exclude'] || []).include? mod }
          .each do |mod|
            begin
              mod_file = mod + '.rb'
              spectre_lib_mod = File.join(File.dirname(__dir__), mod_file)

              if File.exists? mod_file
                Kernel.load mod_file

              else File.exists? spectre_lib_mod
                Kernel.load spectre_lib_mod

              end
            rescue LoadError => e
              puts "Unable to load module #{mod}. Check if the module exists or remove it from your spectre config:\n#{e.message}"
              exit 1
            end
          end
      end
    end
  end

  @@current = nil
  @@mutex = Mutex.new

  def self.register mod
    @@current.register(mod)
  end

  def self.scope spectre_scope
    mutex.synchronize do
      @@current = spectre_scope

      yield

      @@current = nil
    end
  end

  # class << self
  #   @@subjects = []
  #   @@modules = []

  #   def subjects
  #     @@subjects
  #   end

  #   def specs spec_filter=[], tags=[]
  #     @@subjects
  #       .map { |x| x.specs }
  #       .flatten
  #       .select do |spec|
  #         (spec_filter.empty? or spec_filter.any? { |x| spec.name.match('^' + x.gsub('*', '.*') + '$') }) and (tags.empty? or tags.any? { |x| tag?(spec.tags, x) })
  #       end
  #   end

  #   def tag? tags, tag_exp
  #     tags = tags.map { |x| x.to_s }
  #     all_tags = tag_exp.split('+')
  #     included_tags = all_tags.select { |x| !x.start_with? '!' }
  #     excluded_tags = all_tags.select { |x| x.start_with? '!' }.map { |x| x[1..-1] }
  #     included_tags & tags == included_tags and excluded_tags & tags == []
  #   end

  #   def delegate *method_names, to: nil
  #     Delegator.delegate(*method_names, to)
  #   end

  #   def register mod
  #     @@modules << mod
  #   end

  #   def load config
  #     Environment.load(config)

  #     if config.key? 'spec_patterns'
  #       config['spec_patterns'].each do |pattern|
  #         Dir.glob(pattern).each do|f|
  #           Kernel.load File.join(config['working_dir'], f)
  #         end
  #       end
  #     end
  #   end

  #   def configure config
  #     Logging.configure(config)

  #     @@modules.each do |mod|
  #       mod.configure(config) if mod.respond_to? :configure
  #     end
  #   end

  #   def run specs, config={}
  #     if config.key? 'modules'
  #       config['modules']
  #         .concat(config['include'] || [])
  #         .select { |mod| !(config['exclude'] || []).include? mod }
  #         .each do |mod|
  #           begin
  #             mod_file = mod + '.rb'
  #             spectre_lib_mod = File.join(File.dirname(__dir__), mod_file)

  #             if File.exists? mod_file
  #               require_relative mod_file

  #             elsif File.exists? spectre_lib_mod
  #               require_relative spectre_lib_mod

  #             else
  #               require mod
  #             end
  #           rescue LoadError => e
  #             puts "Unable to load module #{mod}. Check if the module exists or remove it from your spectre config:\n#{e.message}"
  #             exit 1
  #           end
  #         end
  #     end

  #     configure(config)

  #     Runner.run(specs)
  #   end

  #   def purge
  #     @@subjects = []
  #     @@modules = []
  #   end


  #   ###########################################
  #   # Global Functions
  #   ###########################################

  #   def describe desc, &block
  #     subject = @@subjects.find { |x| x.desc == desc }

  #     unless subject
  #       subject = Subject.new(desc)
  #       @@subjects << subject
  #     end

  #     ctx = SpecContext.new(subject)
  #     ctx._evaluate &block
  #   end

  #   def property key, val
  #     Logging.log("Set property #{key} to #{val}", :info)
  #     Runner.current.properties[key] = val
  #   end

  #   def group desc
  #     Logging.log("Start #{desc}", :info)
  #     Eventing.trigger(:group, desc) do
  #       yield
  #     end
  #     Logging.log("Finished #{desc}", :info)
  #   end

  #   def skip message=nil
  #     Logging.log("Skipped #{Runner.current.desc}", :info)
  #     raise SpectreSkip.new(message)
  #   end

  #   def bag
  #     Environment.put(:spectre_bag, OpenStruct.new) unless Environment.is_defined?(:spectre_bag)
  #     Environment.bucket(:spectre_bag)
  #   end
  # end

  # delegate(:describe, :property, :group, :skip, :bag, to: self)
  # delegate(:log, :info, :debug, to: Eventing)
  # delegate(:env, to: Environment)
end


extend Spectre::Delegator
