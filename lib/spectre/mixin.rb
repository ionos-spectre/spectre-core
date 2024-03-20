require_relative '../spectre'
require_relative 'logging'

require 'ostruct'

module Spectre
  module Mixin
    class MixinContext < Spectre::DslClass
      def initialize desc
        @__desc = desc
      end

      def required params, *keys
        missing_keys = keys.select { |x| !params.to_h.key? x }
        Spectre::Logging.log_debug("required parameters for '#{@__desc}': #{keys.join ', '}")
        raise ArgumentError, "mixin '#{@__desc}' requires #{keys.join ', '}, but only has #{missing_keys.join ', '} given" unless missing_keys.empty?
      end

      def optional params, *keys
        Spectre::Logging.log_debug("optional parameters for '#{@__desc}': #{keys.join ', '}")
        params
      end
    end

    class << self
      @@mixins = {}

      def mixin desc, &block
        @@mixins[desc] = block
      end

      def run desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless @@mixins.key? desc

        Spectre::Logging.log_debug "running mixin '#{desc}'"

        params = with || {}
        if params.empty?
          params = {}
        end

        ctx = MixinContext.new(desc)

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
