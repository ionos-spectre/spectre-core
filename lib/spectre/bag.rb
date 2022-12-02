require_relative '../spectre'

require 'ostruct'

module Spectre
  module Bag
    class << self
      @@bag = OpenStruct.new

      def bag
        @@bag
      end
    end

    Spectre.delegate :bag, to: self
  end
end
