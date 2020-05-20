require 'securerandom'

class String
  def as_json
    JSON.parse(self)
  end

  def as_date
    DateTime.parse(self)
  end
end

def uuid length = 5
  SecureRandom.uuid().gsub('-', '')[0..length]
end