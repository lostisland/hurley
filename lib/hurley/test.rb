module Hurley
  class Test
    def initialize
      @handlers = []
      yield self if block_given?
    end

    def head(url)
      handle(:head, url, &Proc.new)
    end

    def get(url)
      handle(:get, url, &Proc.new)
    end

    def put(url)
      handle(:put, url, &Proc.new)
    end

    def post(url)
      handle(:post, url, &Proc.new)
    end

    def patch(url)
      handle(:patch, url, &Proc.new)
    end

    def delete(url)
      handle(:delete, url, &Proc.new)
    end

    def options(url)
      handle(:options, url, &Proc.new)
    end

    def handle(verb, url)
      @handlers << Handler.new(Request.new(verb, Url.parse(url)), Proc.new)
    end

    def call(request)
      handler = @handlers.detect { |h| h.matches?(request) } ||
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

      def self.not_found(request)
        Response.new(request, 404, Header.new) do |res|
          res.receive_body("no test handler")
        end
      end

      def initialize(request, callback)
        @request = request
        @callback = callback
        @path_regex = %r{\A#{@request.url.path}(/|\z)}
      end

      def call(request)
        @run = true
        status, header, body = @callback.call(request)
        Response.new(request, status, Header.new(header)) do |res|
          Array(body).each do |chunk|
            res.receive_body(chunk)
          end
        end
      end

      def matches?(request)
        return false unless @request.verb == request.verb

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

      EMPTY_OR_SLASH = %r{\A/?\z}
      URL_ATTRS = [:scheme, :host, :port]
    end
  end
end
