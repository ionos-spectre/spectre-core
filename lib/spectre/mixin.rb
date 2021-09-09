require 'ostruct'

module Spectre
  module Mixin
    class << self
      @@mixins = {}

      def mixin desc, &block
        @@mixins[desc] = block
      end

      def run desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless @@mixins.key? desc
        Logger.log_debug "running mixin '#{desc}'"

        if with.is_a? Array
          @@mixins[desc].call *with
        else
          @@mixins[desc].call with
        end
      end

      alias_method :also, :run
      alias_method :step, :run
    end

    Spectre.delegate :mixin, :run, :also, :step, to: Mixin
  end
end