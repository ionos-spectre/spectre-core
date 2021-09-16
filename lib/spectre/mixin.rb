require 'ostruct'
require 'spectre/logger'

module Spectre
  module Mixin
    class << self
      @@mixins = {}

      def mixin desc, &block
        @@mixins[desc] = block
      end

      def run desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless @@mixins.key? desc

        Spectre::Logger.log_debug "running mixin '#{desc}'"

        params = with || {}

        if params.is_a? Array
          @@mixins[desc].call *params
        elsif params.is_a? Hash
          @@mixins[desc].call OpenStruct.new(params)
        else
          @@mixins[desc].call params
        end
      end

      alias_method :also, :run
      alias_method :step, :run
    end

    Spectre.delegate :mixin, :run, :also, :step, to: Mixin
  end
end