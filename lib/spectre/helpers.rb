require_relative '../spectre'

require 'securerandom'
require 'json'
require 'date'
require 'ostruct'
require 'jsonpath'

class ::String
  def as_json
    JSON.parse(self, object_class: OpenStruct)
  end

  def as_date
    DateTime.parse(self)
  end

  def as_timestamp
    DateTime.parse(self).to_time.to_i
  end

  def with mapping
    return self unless mapping and mapping.is_a? Hash

    new_string = self

    mapping.each do |key, value|
      new_string = new_string.gsub('#{' + key.to_s + '}', value.to_s)
    end

    new_string
  end

  def trim size = 50
    if (self.length + 3) > size
      return self[0..size-4] + '...'
    end

    self
  end

  def pick path
    raise ArgumentError.new("`path' must not be nil or empty") if path.nil? or path.empty?

    begin
      JsonPath.on(self, path)
    rescue MultiJson::ParseError
      # do nothing and return nil
    end
  end

  # File helpers

  def content with: nil
    fail "'#{self}' is not a file path, or the file does not exist." unless File.exists? self

    file_content = File.read(self)

    if with
      file_content.with(with)
    else
      file_content
    end
  end

  def file_size
    fail "'#{self}' is not a file path, or the file does not exist." unless File.exists? self

    File.size(self)
  end

  def exists?
    File.exists? self
  end

  def remove!
    fail "'#{self}' is not a file path, or the file does not exist." unless File.exists? self

    File.delete self
  end
end

class ::OpenStruct
  def to_json *args, **kwargs
    self.to_h.inject({}) { |memo, (k,v)| memo[k] = v.is_a?(OpenStruct) ? v.to_h : v; memo }.to_json(*args, **kwargs)
  end

  def pick path
    raise ArgumentError.new("`path' must not be nil or empty") if path.nil? or path.empty?

    JsonPath.on(self, path)
  end

  def default_to! defaults
    defaults.each_key do |key|
      unless self[key] != nil
        self[key] = defaults[key]
      end
    end
  end

  alias :defaults_to! :default_to!
end

class ::Hash
  def symbolize_keys
    self.inject({}) { |memo, (k,v)| memo[k.to_sym] = v; memo }
  end

  def default_to! defaults
    defaults.each_key do |key|
      unless self[key] != nil
        self[key] = defaults[key]
      end
    end
  end

  alias :defaults_to! :default_to!
end

class ::Array
  def first_element
    self[0]
  end

  def last_element
    self[-1]
  end
end

def uuid length = 5
  SecureRandom.uuid().gsub('-', '')[0..length-1]
end

def now
  Time.now
end
