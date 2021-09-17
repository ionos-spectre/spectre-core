require 'ostruct'

module Spectre
  module Resources
    class ResourceCollection
      def initialize
        @items = {}
      end

      def add name, path
        @items[name] = path
      end

      def [] name
        raise "Resource with name '#{name}' does not exist" if not @items.key? name

        @items[name]
      end
    end

    class << self
      @@resources = ResourceCollection.new

      def resources
        @@resources
      end
    end

    Spectre.register do |config|
      return if !config.key? 'resource_paths'

      config['resource_paths'].each do |resource_path|
        resource_files = Dir.glob File.join(resource_path, '**/*')

        resource_files.each do |file|
          file.slice! resource_path
          file = file[1..-1]
          @@resources.add file, File.expand_path(File.join resource_path, file)
        end
      end

      @@resources.freeze
    end

    Spectre.delegate :resources, to: self
  end
end