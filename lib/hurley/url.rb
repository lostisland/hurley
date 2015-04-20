require "base64"
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
      else new(@@parser.call(raw_url.to_s))
      end
    end

    def initialize(parsed)
      @parsed = parsed
      if u = @parsed.user
        @user = CGI.unescape(u)
        @parsed.user = nil
      else
        @user = nil
      end

      if pwd = @parsed.password
        @password = CGI.unescape(pwd)
        @parsed.password = nil
      else
        @password = nil
      end

      @parsed.userinfo = nil
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

    attr_accessor :user
    attr_accessor :password

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
      @query ||= query_class.parse(@parsed.query)
    end

    def join(relative)
      has_host = false

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

      if relative.host
        has_host = true
      else
        relative.host = host
      end

      if has_host && relative.host != host
        relative.user = relative.password = nil
      else
        relative.user ||= user
        relative.password ||= password
      end

      if relative.scheme
        has_host = true
      else
        relative.scheme = scheme
      end

      inferred_port = INFERRED_PORTS[relative.scheme]
      if !has_host && relative.port == inferred_port
        relative.port = port == inferred_port ? nil : port
      end

      relative
    end

    def request_uri
      req_path = path
      req_path = SLASH if req_path.empty?

      if (q = query.to_query_string).empty?
        req_path
      else
        "#{req_path}?#{q}"
      end
    end

    def to_s
      @parsed.query = raw_query
      @parsed.to_s
    end

    def raw_query
      if (q = query.to_query_string).empty?
        nil
      else
        q
      end
    end

    def raw_query=(new_query)
      @query = nil
      @parsed.query = new_query
    end

    def basic_auth
      return unless @user
      userinfo = @password ? "#{@user}:#{@password}" : @user
      "Basic #{Base64.encode64(userinfo).gsub(/\n/, EMPTY)}"
    end

    def query_class
      @query_class ||= Query.default
    end

    def query_class=(new_query)
      @query = query ? new_query.new(@query) : nil
      @query_class = new_query
    end

    def inspect
      "#<%s %s>" % [
        self.class.name,
        to_s,
      ]
    end

    private

    @@parser = URI.method(:parse)

    EMPTY = "".freeze
    SLASH = "/".freeze

    INFERRED_PORTS = {
      "https" => 443,
      "http" => 80,
    }.freeze

    class Empty < self
      def initialize
        @parsed = @@parser.call(EMPTY)
        @query = Query.parse(EMPTY)
      end

      def relation_with(url)
        :diff
      end
    end
  end
end
