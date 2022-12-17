require_relative '../spectre/core'

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
      def initialize mixin_ctx
        @mixin_ctx = mixin_ctx
      end

      def mixin desc, &block
        @mixin_ctx.mixins[desc] = block
      end
    end

    class MixinExtensions
      attr_reader :mixins
      attr_accessor :run

      def initialize config, logger
        @config = config
        @logger = logger
        @mixins = {}
        @run = nil
      end

      def run desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless @mixins.key? desc

        @logger.debug("running mixin '#{desc}'")

        block = @mixins[desc]
        params = with || {}

        ctx = MixinContext.new(desc, @logger)

        if params.is_a? Array
          return_val = @run.instance_exec(*params, &block)
        elsif params.is_a? Hash
          return_val = @run.instance_exec(OpenStruct.new(params), &block)
        else
          return_val = @run.instance_exec(params, &block)
        end

        return_val.is_a?(Hash) ? OpenStruct.new(return_val) : return_val
      end

      alias_method :also, :run
      alias_method :step, :run

      def load_mixins mixin_patterns, working_dir
        setup_ctx = MixinSetupContext.new(self)

        mixin_patterns.each do |pattern|
          pattern = File.join(working_dir, pattern)
          
          Dir.glob(pattern).each do |mixin_file|
            file_content = File.read(mixin_file)
            setup_ctx.instance_eval(file_content, mixin_file, 1)
          end
        end
      end
    end
  end
end

define 'spectre/mixin' do |config, logger|
  extensions = Spectre::Mixin::MixinExtensions.new(config, logger)
  extensions.load_mixins(config['mixin_patterns'], config['working_dir'])

  register :run, :step, :also, extensions
end