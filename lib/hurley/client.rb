require "forwardable"
require "set"
require "stringio"

module Hurley
  class Client
    attr_reader :url
    attr_reader :header
    attr_writer :connection
    attr_reader :request_options
    attr_reader :ssl_options

    def initialize(endpoint = nil)
      @before_callbacks = []
      @after_callbacks = []
      @url = Url.parse(endpoint)
      @header = Header.new :user_agent => Hurley::USER_AGENT
      @connection = nil
      @request_options = RequestOptions.new
      @ssl_options = SslOptions.new
      yield self if block_given?
    end

    extend Forwardable
    def_delegators(:@url,
      :query,
      :scheme, :scheme=,
      :host, :host=,
      :port, :port=,
    )

    def connection
      @connection ||= Hurley.default_connection
    end

    def head(path, query = nil)
      req = request(:head, path)
      req.query.update(query) if query
      yield req if block_given?
      call(req)
    end

    def get(path, query = nil)
      req = request(:get, path)
      req.query.update(query) if query
      yield req if block_given?
      call(req)
    end

    def patch(path, body = nil, ctype = nil)
      req = request(:patch, path)
      req.body = body if body
      req.header[:content_type] = ctype if ctype
      yield req if block_given?
      call(req)
    end

    def put(path, body = nil, ctype = nil)
      req = request(:put, path)
      req.body = body if body
      req.header[:content_type] = ctype if ctype
      yield req if block_given?
      call(req)
    end

    def post(path, body = nil, ctype = nil)
      req = request(:post, path)
      req.body = body if body
      req.header[:content_type] = ctype if ctype
      yield req if block_given?
      call(req)
    end

    def delete(path, query = nil)
      req = request(:delete, path)
      req.query.update(query) if query
      yield req if block_given?
      call(req)
    end

    def options(path, query = nil)
      req = request(:options, path)
      req.query.update(query) if query
      yield req if block_given?
      call(req)
    end

    def call(request)
      call_with_redirects(request, [])
    end

    def before_call(name_or_callback = nil)
      @before_callbacks << (block_given? ?
        NamedCallback.for(name_or_callback, Proc.new) :
        NamedCallback.for(nil, name_or_callback))
    end

    def after_call(name_or_callback = nil)
      @after_callbacks << (block_given? ?
        NamedCallback.for(name_or_callback  , Proc.new) :
        NamedCallback.for(nil, name_or_callback))
    end

    def before_callbacks
      @before_callbacks.map(&:name)
    end

    def after_callbacks
      @after_callbacks.map(&:name)
    end

    def request(method, path)
      Request.new(method, Url.join(@url, path), @header.dup, nil, @request_options.dup, @ssl_options.dup)
    end

    private

    def call_with_redirects(request, via)
      @before_callbacks.each { |cb| cb.call(request) }

      request.prepare!
      response = connection.call(request)

      @after_callbacks.each { |cb| cb.call(response) }

      if response.automatically_redirect?(via)
        return call_with_redirects(response.location, via << request)
      end

      response.via = via
      response
    end
  end

  class Request < Struct.new(:verb, :url, :header, :body, :options, :ssl_options)
    extend Forwardable
    def_delegators(:url,
      :query,
      :scheme, :scheme=,
      :host, :host=,
      :port, :port=,
    )

    def options
      self[:options] ||= RequestOptions.new
    end

    def ssl_options
      self[:ssl_options] ||= SslOptions.new
    end

    def query_string
      url.query.to_query_string
    end

    def body_io
      return unless body

      if body.respond_to?(:read)
        body
      elsif body
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

    def prepare!
      prepare_basic_auth!

      if body
        prepare_body!
      else
        return unless REQUIRED_BODY_VERBS.include?(verb)
      end

      prepare_content_length!
    end

    private

    def prepare_basic_auth!
      value = !header[:authorization] && url.basic_auth
      header[:authorization] = value if value
    end

    def prepare_body!
      ctype = nil
      case body
      when Query
        ctype, io = body.to_form
        self.body = io
      when Hash
        ctype, io = options.build_form(body)
        self.body = io
      end
      header[:content_type] ||= ctype || DEFAULT_TYPE
    end

    def prepare_content_length!
      if header.key?(:content_length) || header[:transfer_encoding] == CHUNKED
        return
      end

      if body
        if sizer = SIZE_METHODS.detect { |method| body.respond_to?(method) }
          header[:content_length] = body.send(sizer).to_i
        else
          header[:transfer_encoding] = CHUNKED
        end
      else
        header[:content_length] = 0
      end
    end

    def body_receiver
      @body_receiver ||= [nil, BodyReceiver.new]
    end

    DEFAULT_TYPE = "application/octet-stream".freeze
    CHUNKED = "chunked".freeze
    REQUIRED_BODY_VERBS = Set.new([:put, :post])
    SIZE_METHODS = [:bytesize, :length, :size]
  end

  class Response
    attr_reader :request
    attr_reader :header
    attr_accessor :body
    attr_accessor :status_code
    attr_writer :via

    def initialize(request, status_code = nil, header = nil)
      @request = request
      @status_code = status_code
      @header = header || Header.new
      @body = nil
      @receiver = nil
      @timing = nil
      @started_at = Time.now.to_f
      if block_given?
        yield self
        complete!
      end
    end

    def complete!
      @ended_at = Time.now.to_f
      if @receiver.respond_to?(:join)
        @body = @receiver.join
      end
    end

    def via
      @via ||= []
    end

    def location
      @location ||= begin
        return unless loc = @header[:location]
        verb = STATUS_FORCE_GET.include?(status_code) ? :get : request.verb
        Request.new(verb, request.url.join(Url.parse(loc)), request.header, request.body, request.options, request.ssl_options)
      end
    end

    def status_type
      @status_type ||= STATUS_TYPES.detect { |t| send("#{t}?") } || :other
    end

    def redirection?
      STATUS_REDIRECTION.include?(status_code)
    end

    def success?
      status_code > 199 && status_code < 300
    end

    def client_error?
      status_code > 399 && status_code < 500
    end

    def server_error?
      status_code > 499 && status_code < 600
    end

    def automatically_redirect?(previous_requests = nil)
      return false unless redirection?
      limit = request.options.redirection_limit.to_i
      limit > 0 && Array(previous_requests).size < limit
    end

    def receive_body(chunk)
      return if chunk.nil?

      if @receiver.nil?
        statuses, receiver = request.send(:body_receiver)
        @receiver = if statuses && !statuses.include?(@status_code)
          BodyReceiver.new
        else
          receiver
        end
      end

      @receiver.call(self, chunk)
    end

    def ms
      @timing ||= ((@ended_at - @started_at) * 1000).to_i
    end

    def inspect
      "#<%s %s %s == %d%s %dms>" % [
        self.class.name,
        @request.verb.to_s.upcase,
        @request.url.to_s,
        @status_code.to_i,
        @body ? " (#{@body.bytesize} bytes)" : nil,
        ms,
      ]
    end

    STATUS_TYPES = [:success, :redirection, :client_error, :server_error]
    STATUS_FORCE_GET = Set.new([301, 302, 303])
    STATUS_REDIRECTION = STATUS_FORCE_GET + [307, 308]
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
        new(name, callback)
      end
    end

    def name
      self[:name] ||= callback.inspect
    end

    def call(arg)
      callback.call(arg)
    end
  end
end
