require 'ostruct'

module Spectre
  module Mixin
    class << self
      @@mixins = {}

      def mixin desc, &block
        @@mixins[desc] = block
      end

      def run desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless @@mixins.has_key? desc
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

    Spectre.register do |config|
      if not config.has_key? 'mixin_patterns'
        return
      end

      config['mixin_patterns'].each do |pattern|
        Dir.glob(pattern).each do|f|
          require_relative File.join(Dir.pwd, f)
        end
      end
    end

    Spectre.delegate :mixin, :run, :also, :step, to: Mixin
  end
end