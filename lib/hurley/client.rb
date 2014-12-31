require "forwardable"

module Hurley
  class Client
    attr_reader :url
    attr_reader :header
    attr_accessor :connection

    def initialize(endpoint)
      @url = Url.parse(endpoint)
      @header = Header.new
      @connection = nil
    end

    extend Forwardable
    def_delegators(:@url,
      :query,
      :scheme, :scheme=,
      :host, :host=,
      :port, :port=,
    )

    def call(request)
      if !@connection.respond_to?(:call)
        raise ArgumentError, "The client connection is invalid: #{@connection.inspect}"
      end

      @connection.call(request)
    end

    def request(method, path)
      Request.new(self, method, Url.join(@url, path), @header.dup)
    end

    def request!(*args)
      request(*args).call
    end
  end

  class Request < Struct.new(:client, :verb, :url, :header)
    def call
      client.call(self)
    end
  end

  class Response < Struct.new(:request, :status_code, :header, :body)
  end
end
