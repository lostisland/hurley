require "uri"
require "erb"
require "forwardable"

module Hurley
  class Url
    extend Forwardable

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
        relative.path = "#{absolute.path}/#{relative.path}"
      else
        raise "Invalid relation #{relation.inspect} between #{absolute.to_s.inspect} and #{relative.to_s.inspect}"
      end

      relative
    end

    def_delegators(:@parsed,
      :scheme, :scheme=,
      :host, :host=,
      :port, :port=,
    )

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
      return :diff if path.empty?

      query.each do |key, value|
        return :diff unless !url.query.key?(key) || url.query[key] == value
      end

      url_path = url.path
      if url_path =~ EMPTY_OR_RELATIVE
        url_path.size.zero? ? :empty : :relative
      elsif url_path =~ parent_path_regex
        :extended
      else
        :diff
      end
    end

    def parent_path_regex
      @parent_path_regex ||= %r{\A#{path}(/|\z)}
    end

    SLASH = "/".freeze
    EMPTY_OR_RELATIVE = %r{\A([^/]|\z)}
    INFERRED_PORTS = {
      "https" => 443,
      "http" => 80,
    }.freeze
  end
end
