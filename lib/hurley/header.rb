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
      @hash[canonical(key)]
    end

    def []=(key, value)
      @hash[canonical(key)] = value.to_s
    end

    def key?(key)
      @hash.key?(canonical(key))
    end

    def delete(key)
      @hash.delete(canonical(key))
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

    def canonical(key)
      KEYS[key] || key.to_s
    end

    def self.canonical(key)
      KEYS[key] || key.to_s
    end

    # hash of "shortcut key" => "canonical header key"
    KEYS = {}
    [
      "Accept",
      "Content-Type",
      "Content-Length",
      "User-Agent",
    ].each do |canonical|
      KEYS[canonical] = canonical
      shortcut = canonical.downcase
      KEYS[shortcut] = canonical
      shortcut.gsub!("-", "_")
      KEYS[shortcut] = canonical
      KEYS[shortcut.to_sym] = canonical
    end
  end
end
