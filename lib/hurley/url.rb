require "uri"
require "erb"
require "forwardable"

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
      absolute = parse(absolute)
      relative = parse(relative)
      relation = absolute.send(:relation_with, relative)
      case relation
      when :diff  then return relative
      when :empty then return absolute
      when :extended
        relative.merge(absolute)
      when :relative
        relative.merge(absolute)
        joiner = absolute.path =~ ENDING_SLASH ? nil : SLASH
        relative.path = "#{absolute.path}#{joiner}#{relative.path}"
      else
        raise "Invalid relation #{relation.inspect} between #{absolute.to_s.inspect} and #{relative.to_s.inspect}"
      end

      relative
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
      @parent_path_regex = nil
      @parsed.path = new_path
    end

    def query
      @query ||= query_parser.call(@parsed.query)
    end

    def parent_of?(url)
      return relation_with(url) != :diff
    end

    def query_parent_of?(url)
      url_query = url.respond_to?(:query) ? url.query : url
      query.each do |key, value|
        return false unless !url_query.key?(key) || url_query[key] == value
      end
      true
    end

    def path_parent_of?(url)
      url_path = url.respond_to?(:path) ? url.path : url.to_s
      path_relation_with(url_path) != :diff
    end

    def merge(url)
      @parsed.scheme = url.scheme
      @parsed.host = url.host
      query.merge(url.query)

      new_port = url.port
      if INFERRED_PORTS[@parsed.scheme] == new_port
        @parsed.port = nil
      else
        @parsed.port = new_port
      end
    end

    def request_uri
      if (q = query.encode).empty?
        path
      else
        "#{path}?#{q}"
      end
    end

    def to_s
      if (q = query.encode).empty?
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

    private

    def relation_with(url)
      return :diff if url.scheme && url.scheme != scheme
      return :diff if url.host && url.host != host
      return :diff if url.port && url.port != port
      return :diff unless query_parent_of?(url.query)
      path_relation_with(url.path)
    end

    def path_relation_with(url_path)
      if url_path =~ EMPTY_OR_RELATIVE
        url_path.size.zero? ? :empty : :relative
      elsif path =~ EMPTY_OR_SLASH || url_path =~ parent_path_regex
        :extended
      else
        :diff
      end
    end

    def parent_path_regex
      @parent_path_regex ||= %r{\A#{path}(/|\z)}
    end

    EMPTY = "".freeze
    SLASH = "/".freeze
    ENDING_SLASH = %r{/\z}
    EMPTY_OR_RELATIVE = %r{\A([^/]|\z)}
    EMPTY_OR_SLASH = %r{\A/?\z}
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
