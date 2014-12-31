module Hurley
  VERSION = "0.1".freeze
  USER_AGENT = "Hurley v#{VERSION}".freeze
  LIB_PATH = __FILE__[0...-3]

  def self.require_lib(*libs)
    libs.each do |lib|
      require File.join(LIB_PATH, lib)
    end
  end

  require_lib(
    "url",
  )
end
