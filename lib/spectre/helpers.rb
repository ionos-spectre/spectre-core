class String
  def as_json
    JSON.parse(self)
  end

  def as_date
    DateTime.parse(self)
  end
end
