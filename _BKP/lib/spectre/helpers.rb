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
    fail "'#{self}' is not a file path, or the file does not exist." unless File.exist? self

    file_content = File.read(self)

    if with
      file_content.with(with)
    else
      file_content
    end
  end

  def file_size
    fail "'#{self}' is not a file path, or the file does not exist." unless File.exist? self

    File.size(self)
  end

  def exist?
    File.exist? self
  end

  def remove!
    fail "'#{self}' is not a file path, or the file does not exist." unless File.exist? self

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
  def first_item
    self[0]
  end

  def second_item
    self[1]
  end

  def third_item
    self[2]
  end

  def fourth_item
    self[3]
  end

  def fifth_item
    self[4]
  end

  def last_item
    self[-1]
  end
end

def uuid length = nil
  return SecureRandom.hex(length/2) if length

  SecureRandom.uuid
end

def now
  Time.now
end
