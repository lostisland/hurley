module Hurley
  class Test
    def initialize
      @handlers = []
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

    def delete(url)
      handle(:delete, url, &Proc.new)
    end

    def handle(verb, url)
      @handlers << Handler.new(Request.new(self, verb, Url.parse(url)), Proc.new)
    end

    def call(request)
      handler = @handlers.detect { |h| h.matches?(request) } ||
        self.class.method(:not_found)
      handler.call(request)
    end

    def all_run?
      @handlers.all?(&:run?)
    end

    class Handler < Struct.new(:request, :callback)
      def call(request)
        @run = true
        status, header, body = callback.call(request)
        res = Response.new(request, status, Header.new(header))
        res.receive_body(body)
        res.finish
      end

      def matches?(request)
        return false unless self.request.verb == request.verb

        handler_url = self.request.url
        if handler_url.host.to_s.empty?
          handler_url.path_parent_of?(request.url) &&
            handler_url.query_parent_of?(request.url)
        else
          handler_url.parent_of?(request.url)
        end
      end

      def run?
        !!@run
      end
    end

    def self.not_found(request)
      Response.new(request, 404, Header.new, "no test handler")
    end
  end
end
