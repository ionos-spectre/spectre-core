require 'ostruct'

module Spectre
  module Bag
    class << self
      @@bag

      def bag
        @@bag
      end
    end

    Spectre.register do |config|
      @@bag = OpenStruct.new config
    end

    Spectre.delegate :bag, to: Bag
  end
end