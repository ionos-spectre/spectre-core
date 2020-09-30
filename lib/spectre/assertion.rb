class Object
  def should_be(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.to_s == val.to_s
  end

  def should_be_empty
    raise Spectre::ExpectationFailure.new(val, self) unless self == nil
  end

  def should_not_be(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.to_s != val.to_s
  end

  def should_not_be_empty
    raise Spectre::ExpectationFailure.new(val, self) unless self != nil
  end
end


class Hash
  def should_contain(other)
    raise Spectre::ExpectationFailure.new(other, self) unless self.merge(other) == self
  end

  def should_not_contain(other)
    raise Spectre::ExpectationFailure.new(other, self) unless self.merge(other) != self
  end
end


class Array
  def should_contain(val)
    raise Spectre::ExpectationFailure.new(val, self) unless self.include? val
  end

  def should_not_contain(val)
    raise Spectre::ExpectationFailure.new(val, self) if self.include? val
  end

  def should_be_empty
    raise Spectre::ExpectationFailure.new(val, self) unless self.length == 0
  end

  def should_not_be_empty
    raise Spectre::ExpectationFailure.new(val, self) unless self.length > 0
  end
end


class String
  def should_contain(val)
      raise Spectre::ExpectationFailure.new(val, self) unless self.include? val
  end

  def should_contain(val)
      raise Spectre::ExpectationFailure.new(val, self) if self.include? val
  end

  def should_match(regex)
    raise Spectre::ExpectationFailure.new(regex, self) unless self.match(regex)
  end

  def should_not_match(regex)
    raise Spectre::ExpectationFailure.new(regex, self) if self.match(regex)
  end
end