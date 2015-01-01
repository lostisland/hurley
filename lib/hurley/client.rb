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
      req = Request.new(self, method, Url.join(@url, path), @header.dup)
      if block_given?
        yield req
        req.call
      else
        req
      end
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

    def on_body(*statuses)
      @body_receiver = [statuses.empty? ? nil : statuses, Proc.new]
    end

    def inspect
      "#<%s %s %s>" % [
        self.class.name,
        verb.to_s.upcase,
        url.to_s,
      ]
    end

    def body_receiver
      @body_receiver ||= [nil, BodyReceiver.new]
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
      @receiver = nil
      yield self
      if @receiver.respond_to?(:join)
        @body = @receiver.join
      end
    end

    def receive_body(chunk)
      if @receiver.nil?
        statuses, receiver = request.body_receiver
        @receiver = if statuses && !statuses.include?(@status_code)
          BodyReceiver.new
        else
          receiver
        end
      end
      @receiver.call(self, chunk)
    end

    def inspect
      "#<%s %s %s == %d%s>" % [
        self.class.name,
        @request.verb.to_s.upcase,
        @request.url.to_s,
        @status_code.to_i,
        @body ? " (#{@body.bytesize} bytes)" : nil,
      ]
    end
  end

  class BodyReceiver
    def initialize
      @chunks = []
    end

    def call(res, chunk)
      @chunks << chunk
    end

    def join
      @chunks.join
    end
  end
end
