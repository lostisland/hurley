require "forwardable"

module Hurley
  class Header
    def initialize(initial = nil)
      @hash = {}
      merge(initial) if initial
    end

    extend Forwardable
    def_delegators(:@hash,
      :each,
      :keys,
      :size,
    )

    def [](key)
      @hash[self.class.canonical(key)]
    end

    def []=(key, value)
      @hash[self.class.canonical(key)] = value.to_s
    end

    def key?(key)
      @hash.key?(self.class.canonical(key))
    end

    def delete(key)
      @hash.delete(self.class.canonical(key))
    end

    def merge(hash)
      hash.each do |key, value|
        self[key] = value
      end
    end

    def dup
      self.class.new(@hash.dup)
    end

    def to_hash
      @hash
    end

    def inspect
      "#<%s %s>" % [
        self.class.name,
        @hash.inspect,
      ]
    end

    def self.canonical(key)
      KEYS[key] || key.to_s
    end

    def self.add_canonical_key(*canonicals)
      canonicals.each do |canonical|
        KEYS[canonical] = canonical
        shortcut = canonical.downcase
        KEYS[shortcut] = canonical
        shortcut.gsub!("-", "_")
        KEYS[shortcut] = canonical
        KEYS[shortcut.to_sym] = canonical
      end
    end

    # hash of "shortcut key" => "canonical header key"
    KEYS = {
      "ETag" => "Etag",
    }

    # just common headers, not an exhaustive list
    add_canonical_key(
      "Accept",
      "Access-Control-Allow-Credentials",
      "Access-Control-Allow-Origin",
      "Access-Control-Expose-Headers",
      "Age",
      "Authorization",
      "Cache-Control",
      "Connection",
      "Content-Disposition",
      "Content-Language",
      "Content-Length",
      "Content-MD5",
      "Content-Range",
      "Content-Security-Policy",
      "Content-Type",
      "Cookie",
      "Date",
      "Etag",
      "Expect",
      "Expires",
      "From",
      "Host",
      "If-Modified-Since",
      "If-None-Match",
      "Last-Modified",
      "Link",
      "Location",
      "Origin",
      "Range",
      "Referer",
      "Refresh",
      "Retry-After",
      "Server",
      "Set-Cookie",
      "Status",
      "String-Transport-Security",
      "Trailer",
      "Transfer-Encoding",
      "User-Agent",
      "Upgrade",
      "Vary",
      "Via",
      "WWW-Authenticate",
      "X-Content-Type-Options",
      "X-Frame-Options",
      "X-Powered-By",
      "X-Served-By",
      "X-Xss-Protection",
    )
  end
end
