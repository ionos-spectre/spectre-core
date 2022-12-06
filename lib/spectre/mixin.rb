require_relative '../spectre'
require_relative 'logging'

require 'ostruct'

module Spectre
  module Mixin
    class MixinContext < Spectre::DslClass
      def initialize desc, logger
        @__logger = logger
        @__desc = desc
      end

      def required params, *keys
        missing_keys = keys.select { |x| !params.to_h.key? x }
        @__logger.debug("required parameters for '#{@__desc}': #{keys.join ', '}")
        raise ArgumentError, "mixin '#{@__desc}' requires #{keys.join ', '}, but only has #{missing_keys.join ', '} given" unless missing_keys.empty?
      end

      def optional params, *keys
        @__logger.debug("optional parameters for '#{@__desc}': #{keys.join ', '}")
        params
      end
    end

    class << self
      @@mixins = {}
      @@logger = Spectre::Logging::ModuleLogger.new('spectre/mixin')

      def mixin desc, &block
        @@mixins[desc] = block
      end

      def run desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless @@mixins.key? desc

        @@logger.debug "running mixin '#{desc}'"

        params = with || {}

        ctx = MixinContext.new(desc, @@logger)

        if params.is_a? Array
          return_val = ctx._execute(*params, &@@mixins[desc])
        elsif params.is_a? Hash
          return_val = ctx._execute(OpenStruct.new(params), &@@mixins[desc])
        else
          return_val = ctx._execute(params, &@@mixins[desc])
        end

        return_val.is_a?(Hash) ? OpenStruct.new(return_val) : return_val
      end

      alias_method :also, :run
      alias_method :step, :run
    end

    Spectre.delegate :mixin, :run, :also, :step, to: self
  end
end
