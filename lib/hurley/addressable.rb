require "addressable/uri"

module Hurley
  class Url
    @@parser = Addressable::URI.method(:parse)
  end
end
