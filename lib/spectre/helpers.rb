class String
  def as_json
    JSON.parse(self)
  end
end
  