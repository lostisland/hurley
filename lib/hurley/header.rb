require "forwardable"

module Hurley
  class Header
    def initialize(initial = nil)
      @hash = {}
      update(initial) if initial
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

    def update(hash)
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

    def self.canonical(input)
      KEYS[input] || begin
        key = input.to_s.tr(UNDERSCORE, DASH)
        key.downcase!
        key.gsub!(/(\A|\-)(\S)/) { |s| s.upcase! ; s }
        key
      end
    end

    def self.add_canonical_key(*canonicals)
      canonicals.each do |canonical|
        canonical.freeze
        KEYS[canonical] = canonical
        shortcut = canonical.downcase
        KEYS[shortcut.freeze] = canonical
        KEYS[shortcut.tr(DASH, UNDERSCORE).to_sym] = canonical
      end
    end

    private

    # hash of "shortcut key" => "canonical header key"
    # string keys are converted to canonical header names:
    #
    # KEYS["content_type"] # => "Content-Type"
    #
    KEYS = {"ETag".freeze => "Etag".freeze}
    DASH = "-".freeze
    UNDERSCORE = "_".freeze

    # Adds canonical header keys for common headers.
    #
    # KEYS[:content_type]  # => "Content-Type"
    # KEYS["Content-Type"] # => "Content-Type"
    # KEYS["content-type"] # => "Content-Type"
    #
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

    # Some weird exceptions
    KEYS["ETag"] = "Etag"
  end
end
