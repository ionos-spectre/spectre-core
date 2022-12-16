require 'ostruct'

require_relative './spectre/core'

module Spectre
  module Version
    MAJOR = 2
    MINOR = 0
    TINY  = 0
  end

  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].compact * '.'

end
