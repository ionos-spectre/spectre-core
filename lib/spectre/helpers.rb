require 'securerandom'
require 'json'
require 'date'
require 'ostruct'

class ::String
  ##
  # Parses the string as JSON and returns an +OpenStruct+
  #
  def as_json
    JSON.parse(self, object_class: OpenStruct)
  end

  ##
  # Parses the string as a date time object
  #
  def as_date
    DateTime.parse(self)
  end

  ##
  # Parses the string as a date time object and returns it as a unix timestamp
  #
  def as_timestamp
    DateTime.parse(self).to_time.to_i
  end

  ##
  # Replaces placeholder in style of +#{placeholder}+ with the given +Hash+
  #
  def with mapping
    return self unless mapping.is_a? Hash

    new_string = self

    mapping.each do |key, value|
      new_string = new_string.gsub('#{' + key.to_s + '}', value.to_s)
    end

    new_string
  end

  ##
  # Trims the string to the given length and adds +...+ at the end
  def trim size = 50
    return "#{self[0..size - 4]}..." if (length + 3) > size

    self
  end

  ##
  # Interprets the string as a file path and reads its content
  #
  def content with: nil
    raise "'#{self}' is not a file path, or the file does not exist." unless File.exist? self

    file_content = File.read(self)

    if with
      file_content.with(with)
    else
      file_content
    end
  end

  ##
  # Interprets the string as a file path and returns its size
  #
  def file_size
    raise "'#{self}' is not a file path, or the file does not exist." unless File.exist? self

    File.size(self)
  end

  ##
  # Interprets the string as a file path and returns +true+ if is exists, +false+ otherwise
  #
  def exists?
    File.exist? self
  end

  ##
  # Interprets the string as a file path and removes it
  #
  def remove!
    raise "'#{self}' is not a file path, or the file does not exist." unless File.exist? self

    File.delete self
  end
end

class ::OpenStruct
  def each(&)
    to_h.each(&)
  end

  def to_json(*, **)
    to_h
      .transform_values { |x| x.is_a?(OpenStruct) ? x.to_h : x }
      .to_json(*, **)
  end

  def default_to! defaults = {}, **kwargs
    defaults = kwargs if kwargs.any?

    defaults.each_key do |key|
      self[key] = defaults[key] unless to_h.key? key
    end
  end
end

class ::Hash
  def default_to! defaults = {}, **kwargs
    defaults = kwargs if kwargs.any?

    defaults.each_key do |key|
      self[key] = defaults[key] unless key? key
    end
  end
end

module Spectre
  module Helpers
    class << self
      def uuid length = niL
        return SecureRandom.hex(length / 2) if length

        SecureRandom.uuid
      end

      def now
        Time.now
      end
    end
  end
end
