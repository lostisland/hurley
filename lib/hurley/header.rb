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
    KEYS = {}
    add_canonical_key(
      "Accept",
      "Access-Control-Allow-Credentials",
      "Access-Control-Allow-Origin",
      "Acces-Control-Expose-Headers",
      "Cache-Control",
      "Connection",
      "Content-Length",
      "Content-Security-Policy",
      "Content-Type",
      "Date",
      "Etag",
      "Last-Modified",
      "Server",
      "Status",
      "String-Transport-Security",
      "Transfer-Encoding",
      "User-Agent",
      "Vary",
      "X-Content-Type-Options",
      "X-Frame-Options",
      "X-Served-By",
      "X-Xss-Protection",
    )
  end
end
