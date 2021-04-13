require 'securerandom'
require 'json'
require 'date'

class ::String
  def as_json
    JSON.parse(self)
  end

  def as_date
    DateTime.parse(self)
  end

  def content with: nil
    fail "'#{self}' is not a file path, or the file does not exist." if !File.exists? self
    file_content = File.read(self)

    if with
      with.each do |key, value|
        file_content = file_content.gsub '#{' + key.to_s + '}', value
      end
    end

    file_content
  end

  def exists?
    File.exists? self
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