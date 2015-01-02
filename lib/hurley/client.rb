require "forwardable"
require "stringio"

module Hurley
  class Client
    attr_reader :url
    attr_reader :header
    attr_writer :connection
    attr_reader :before_callbacks
    attr_reader :after_callbacks

    def self.default_connection
      @default_connection ||= begin
        Hurley.require_lib "connection"
        Connection.new
      end
    end

    def initialize(endpoint)
      @before_callbacks = []
      @after_callbacks = []
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

    def connection
      @connection ||= self.class.default_connection
    end

    def head(path)
      req = request(:head, path)
      yield req if block_given?
      call(req)
    end

    def get(path)
      req = request(:get, path)
      yield req if block_given?
      call(req)
    end

    def put(path)
      req = request(:put, path)
      yield req if block_given?
      call(req)
    end

    def post(path)
      req = request(:post, path)
      yield req if block_given?
      call(req)
    end

    def delete(path)
      req = request(:delete, path)
      yield req if block_given?
      call(req)
    end

    def options(path)
      req = request(:options, path)
      yield req if block_given?
      call(req)
    end

    def call(request)
      @before_callbacks.each { |cb| cb.call(request) }
      response = connection.call(request)
      @after_callbacks.each { |cb| cb.call(response) }
      response
    end

    def before_call(name = nil)
      @before_callbacks << (block_given? ?
        NamedCallback.for(name, Proc.new) :
        NamedCallback.for(nil, name))
    end

    def after_call(name = nil)
      @after_callbacks << (block_given? ?
        NamedCallback.for(name, Proc.new) :
        NamedCallback.for(nil, name))
    end

    def request(method, path)
      Request.new(method, Url.join(@url, path), @header.dup)
    end
  end

  class Request < Struct.new(:verb, :url, :header, :body)
    def query
      url.query
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
    attr_accessor :body
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

  class NamedCallback < Struct.new(:name, :callback)
    def self.for(name, callback)
      if callback.respond_to?(:name) && !name
        callback
      else
        new(name || :undefined, callback)
      end
    end

    def call(arg)
      callback.call(arg)
    end
  end
end
