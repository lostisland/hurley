require "erb"
require "forwardable"
require "set"
require "uri"

module Hurley
  class Url
    def self.escape_path(path)
      ERB::Util.url_encode(path.to_s)
    end

    def self.escape_paths(*paths)
      paths.map do |path|
        escape_path(path)
      end.join(SLASH)
    end

    def self.parse(raw_url)
      case raw_url
      when Url then raw_url
      when nil, EMPTY then Empty.new
      else new(URI.parse(raw_url.to_s))
      end
    end

    def initialize(parsed)
      @parsed = parsed
    end

    def self.join(absolute, relative)
      parse(absolute).join(parse(relative))
    end

    extend Forwardable
    def_delegators(:@parsed,
      :scheme, :scheme=,
      :host, :host=,
      :port=,
    )

    def port
      @parsed.port || INFERRED_PORTS[@parsed.scheme]
    end

    def path
      @parsed.path
    end

    def path=(new_path)
      @parsed.path = new_path
    end

    def query
      @query ||= query_parser.call(@parsed.query)
    end

    def join(relative)
      relative.scheme ||= scheme
      relative.host ||= host
      relative.port ||= port

      query.each do |key, value|
        relative.query[key] = value unless relative.query.key?(key)
      end

      if !path.empty? && !relative.path.start_with?(SLASH)
        rel_path = relative.path
        relative.path = path
        if !rel_path.empty?
          joiner = path.end_with?(SLASH) ? nil : SLASH
          relative.path += "#{joiner}#{rel_path}"
        end
      end

      if !relative.path.empty? && !relative.path.start_with?(SLASH)
        relative.path = "/#{relative.path}"
      end

      relative
    end

    def request_uri
      if (q = query.to_s).empty?
        path
      else
        "#{path}?#{q}"
      end
    end

    def to_s
      if (q = query.to_s).empty?
        @parsed.query = nil
      else
        @parsed.query = q
      end
      @parsed.to_s
    end

    def raw_query
      @parsed.query
    end

    def raw_query=(new_query)
      @query = nil
      @parsed.query = new_query
    end

    def query_parser
      @query_parser ||= Query.parser_for(nil)
    end

    def query_parser=(new_parser)
      @query_parser = Query.parser_for(new_parser)
    end

    def inspect
      "#<%s %s>" % [
        self.class.name,
        to_s,
      ]
    end

    private

    EMPTY = "".freeze
    SLASH = "/".freeze

    INFERRED_PORTS = {
      "https" => 443,
      "http" => 80,
    }.freeze

    class Empty < self
      def initialize
        @parsed = URI.parse(EMPTY)
        @query = Query.parser_for(nil).call(EMPTY)
      end

      def relation_with(url)
        :diff
      end
    end
  end
end
