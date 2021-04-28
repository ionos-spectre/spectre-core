require 'securerandom'
require 'json'
require 'date'
require 'ostruct'

class ::String
  def as_json
    JSON.parse(self, object_class: OpenStruct)
  end

  def as_date
    DateTime.parse(self)
  end

  def content with: nil
    fail "'#{self}' is not a file path, or the file does not exist." if !File.exists? self
    file_content = File.read(self)

    if with
      with.each do |key, value|
        file_content = file_content.gsub '#{' + key.to_s + '}', value.to_s
      end
    end

    file_content
  end

  def exists?
    File.exists? self
  end

  def remove!
    fail "'#{self}' is not a file path, or the file does not exist." if !File.exists? self

    File.delete self
  end

  def trim count=50
    if (self.length + 3) > count
      return self[0..count] + '...'
    end

    self
  end
end


class ::OpenStruct
  def to_json *args, **kwargs
    self.to_h.inject({}) { |memo, (k,v)| memo[k] = v.is_a?(OpenStruct) ? v.to_h : v; memo }.to_json(*args, **kwargs)
  end
end


class ::Hash
  def symbolize_keys
    self.inject({}) { |memo, (k,v)| memo[k.to_sym] = v; memo }
  end
end


def uuid length = 5
  SecureRandom.uuid().gsub('-', '')[0..length]
end