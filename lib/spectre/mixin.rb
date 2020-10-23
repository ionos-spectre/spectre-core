require 'ostruct'

module Spectre
  module Mixin
    class << self
      @@mixins = {}

      def mixin desc, &block
        @@mixins[desc] = block
      end

      def _mixins
        @@mixins
      end
    end

    class Spectre::SpecContext
      def also desc, tags: []
        raise "no mixin with desc '#{desc}' defined" unless Mixin._mixins.has_key? desc
        @subject.add_spec(desc, tags, [], Mixin._mixins[desc], self)
      end
    end

    class Spectre::RunContext
      def also desc, with: []
        raise "no mixin with desc '#{desc}' defined" unless Mixin._mixins.has_key? desc
        self.instance_exec(*with, &Mixin._mixins[desc])
      end
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

    Spectre.delegate :mixin, to: Mixin
  end
end