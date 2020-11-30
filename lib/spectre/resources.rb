require 'ostruct'

module Spectre
  module Resources
    class << self
      @@resources = {}

      def resources
        @@resources
      end
    end

    Spectre.register do |config|
      return if !config.has_key? 'resource_paths'

      config['resource_paths'].each do |resource_path|
        resource_files = Dir.glob File.join(resource_path, '**/*')

        resource_files.each do |file|
          file.slice! resource_path
          file = file[1..-1]
          @@resources[file] = File.expand_path File.join(resource_path, file)
        end
      end

      @@resources.freeze
    end

    Spectre.delegate :resources, to: Resources
  end
end