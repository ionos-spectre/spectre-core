require_relative '../spectre'

require 'ostruct'

module Spectre
  module Mixin
    # class MixinContext < DslBase
    #   def initialize desc, logger
    #     @__logger = logger
    #     @__desc = desc
    #   end

    #   def required params, *keys
    #     missing_keys = keys.select { |x| !params.to_h.key? x }
    #     @__logger.debug("required parameters for '#{@__desc}': #{keys.join ', '}")
    #     raise ArgumentError, "mixin '#{@__desc}' requires #{keys.join ', '}, but only has #{missing_keys.join ', '} given" unless missing_keys.empty?
    #   end

    #   def optional params, *keys
    #     @__logger.debug("optional parameters for '#{@__desc}': #{keys.join ', '}")
    #     params
    #   end
    # end

    class MixinSetupContext
      attr_reader :mixins

      def initialize
        @mixins = {}
      end

      def mixin desc, &block
        @mixins[desc] = block
      end

      def load_mixins mixin_patterns, working_dir
        mixin_patterns.each do |pattern|
          pattern = File.join(working_dir, pattern)

          Dir.glob(pattern).each do |mixin_file|
            file_content = File.read(mixin_file)
            instance_eval(file_content, mixin_file, 1)
          end
        end
      end
    end

    class MixinExtensions
      attr_reader :mixins

      def initialize config, logger, mixins, run_ctx
        @config = config
        @logger = logger
        @mixins = mixins
        @run_ctx = run_ctx
      end

      def run desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless @mixins.key? desc

        @logger.debug("running mixin '#{desc}'")

        block = @mixins[desc]
        params = with || {}

        if params.is_a? Array
          return_val = @run_ctx.instance_exec(*params, &block)
        elsif params.is_a? Hash
          return_val = @run_ctx.instance_exec(OpenStruct.new(params), &block)
        else
          return_val = @run_ctx.instance_exec(params, &block)
        end

        return_val.is_a?(Hash) ? OpenStruct.new(return_val) : return_val
      end

      alias_method :also, :run
      alias_method :step, :run
    end
  end
end

Spectre.define 'spectre/mixin' do |config, logger, _scope|
  setup_ctx = Spectre::Mixin::MixinSetupContext.new

  unless config['mixin_patterns'].nil?
    setup_ctx.load_mixins(config['mixin_patterns'], config['working_dir'])
  end

  register :run, :step, :also do |run_ctx|
    Spectre::Mixin::MixinExtensions.new(config, logger, setup_ctx.mixins, run_ctx)
  end
end
