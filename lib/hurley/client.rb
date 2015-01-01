require "forwardable"
require "stringio"

module Hurley
  class Client
    attr_reader :url
    attr_reader :header
    attr_accessor :connection

    def self.default_connection
      @default_connection ||= begin
        Hurley.require_lib "connection"
        Connection.new
      end
    end

    def initialize(endpoint)
      @url = Url.parse(endpoint)
      @header = Header.new :user_agent => Hurley::USER_AGENT
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
      @connection ||= self.class.default_connection
      @connection.call(request)
    end

    def request(method, path)
      Request.new(self, method, Url.join(@url, path), @header.dup)
    end

    def request!(*args)
      request(*args).call
    end
  end

  class Request < Struct.new(:client, :verb, :url, :header, :body)
    def query
      url.query
    end

    def call
      if !client.respond_to?(:call)
        raise ArgumentError, "The client is invalid: #{client.inspect}"
      end

      client.call(self)
    end

    def body_io
      if body.respond_to?(:read)
        body
      else
        StringIO.new(body)
      end
    end

    def on_body
      if block_given?
        @body_receiver = Proc.new
      else
        @body_receiver ||= BodyReceiver.new
      end
    end
  end

  class Response
    attr_reader :request
    attr_reader :header
    attr_reader :body
    attr_accessor :status_code

    def initialize(request, status_code = nil, header = nil)
      @request = request
      @status_code = status_code
      @header = header || Header.new
      @body = nil
      yield self
      if request.on_body.respond_to?(:join)
        @body = request.on_body.join
      end
    end

    def receive_body(chunk)
      request.on_body.call(chunk)
    end
  end

  class BodyReceiver
    def initialize
      @chunks = []
    end

    def call(chunk)
      @chunks << chunk
    end

    def join
      @chunks.join
    end
  end
end
