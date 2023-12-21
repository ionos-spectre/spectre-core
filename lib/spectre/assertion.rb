require 'ostruct'

class SpectreFailure < Exception
end

class Object
  def should matcher
    loc = caller_locations
      .select { |x| x.base_label == '<top (required)>' }
      .first

    var_name = File.read(loc.absolute_path)
      .lines[loc.lineno - 1]
      .strip
      .match(/(.*)\.should/)
      .captures
      .first
      .strip

    func, expected_val, matcher_name = matcher

    unless func.call(self)
      raise SpectreFailure.new("Expected #{var_name} to #{matcher_name} #{expected_val}, but got #{self}")
    end
  end

  def should_not matcher
    func, expected_val, matcher_name = matcher
    should([proc { |val| !func.call(val) }, expected_val, "not #{matcher_name}"])
  end
end

def be expected_val
  [proc { |val| val == expected_val }, expected_val, 'be']
end
