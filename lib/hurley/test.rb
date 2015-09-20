module Hurley
  class Test
    def initialize
      @handlers = []
      @handlers_by_verb_and_url = {}
      yield self if block_given?
    end

    def get(url, options = nil)
      handle(:get, url, options, &Proc.new)
    end

    alias head get

    def put(url, options = nil)
      handle(:put, url, options, &Proc.new)
    end

    def post(url, options = nil)
      handle(:post, url, options, &Proc.new)
    end

    def patch(url, options = nil)
      handle(:patch, url, options, &Proc.new)
    end

    def delete(url, options = nil)
      handle(:delete, url, options, &Proc.new)
    end

    def options(url, options = nil)
      handle(:options, url, options, &Proc.new)
    end

    def handle(verb, url, options = nil)
      # treat HEAD responses like GET
      req_verb = verb == :head ? :get : verb
      vu = [req_verb, url]

      if existing = @handlers_by_verb_and_url[vu]
        existing.expires = true
        (options ||= {}).update(:expires => true)
      end

      h = Handler.new(Request.new(req_verb, Url.parse(url)), Proc.new, options)
      @handlers_by_verb_and_url[vu] ||= h
      @handlers << h
    end

    def call(request)
      handler = @handlers.detect { |h| !h.expired? && h.matches?(request) } ||
        Handler.method(:not_found)
      # Create a new url with fresh state from the url string
      request.url = Url.parse(request.url.to_s)
      handler.call(request)
    end

    def all_run?
      @handlers.all?(&:run?)
    end

    class Handler
      attr_reader :request
      attr_reader :callback
      attr_writer :expires

      def self.not_found(request)
        Response.new(request, 404, Header.new) do |res|
          res.receive_body("no test handler")
        end
      end

      def initialize(request, callback, options = nil)
        @run = false
        @request = request
        @callback = callback
        @expires = (options && options[:expires]) ? true : false
        @path_regex = %r{\A#{@request.url.path}(/|\z)}
      end

      def call(request)
        @run = true
        status, header, body = @callback.call(request)
        Response.new(request, status, Header.new(header)) do |res|
          next if request.verb == :head
          Array(body).each do |chunk|
            res.receive_body(chunk)
          end
        end
      end

      def matches?(request)
        verb_to_match = request.verb == :head ? :get : request.verb
        return false unless verb_to_match == @request.verb

        handler_url = @request.url
        request_url = request.url

        URL_ATTRS.each do |attr|
          value = handler_url.send(attr)
          return false if value && value != request_url.send(attr)
        end

        handler_url.query.subset_of?(request_url.query) &&
          (handler_url.path =~ EMPTY_OR_SLASH || request_url.path =~ @path_regex)
      end

      def run?
        !!@run
      end

      def expires?
        @expires
      end

      def expired?
        @expires && run?
      end

      EMPTY_OR_SLASH = %r{\A/?\z}
      URL_ATTRS = [:scheme, :host, :port]
    end
  end
end
