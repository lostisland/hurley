module Hurley
  class Request < Struct.new(:client, :verb, :url, :header)
  end
end
