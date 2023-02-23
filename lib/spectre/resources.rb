require_relative '../spectre'

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
        raise "Resource with name '#{name}' does not exist" unless @items.key? name

        @items[name]
      end

      def resources
        self
      end

      def read_resources path
        path.each do |resource_path|
          resource_files = Dir.glob File.join(resource_path, '**/*')

          resource_files.each do |file|
            file.slice! resource_path
            file = file[1..-1]
            @items[file] = File.expand_path(File.join resource_path, file)
          end
        end

        @items.freeze
      end
    end
  end
end

Spectre.define 'spectre/resources' do |config, logger, _scope|
  resource_collection = Spectre::Resources::ResourceCollection.new

  unless config['resource_paths'].nil?
    resource_collection.read_resources(config['resource_paths'])
  end

  register :resources do |run_ctx|
    resource_collection
  end
end