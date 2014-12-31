require "forwardable"

module Hurley
  class Client
    attr_reader :url
    attr_reader :header

    def initialize(endpoint)
      @url = Url.parse(endpoint)
      @header = {}
    end

    extend Forwardable
    def_delegators(:@url,
      :query,
      :scheme, :scheme=,
      :host, :host=,
      :port, :port=,
    )

    def request(method, path)
      Request.new(self, method, Url.join(@url, path), @header.dup)
    end
  end
end
