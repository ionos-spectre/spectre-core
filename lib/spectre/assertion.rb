class Object
  def should_be(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.to_s == val.to_s
  end

  def should_not_be(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.to_s != val.to_s
  end
end


class Hash
  def should_contain(other)
      raise Spectre::ExpectationFailure.new(other, self) unless self.merge(other) == self
  end
end


class Array
  def should_contain(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.include? val
  end
end