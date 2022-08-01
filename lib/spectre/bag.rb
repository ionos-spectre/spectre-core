require_relative '../spectre'

require 'ostruct'

module Spectre
  module Bag
    class << self
      @@bag

      def bag
        @@bag
      end
    end

    Spectre.register do |_config|
      @@bag = OpenStruct.new
    end

    Spectre.delegate :bag, to: self
  end
end
