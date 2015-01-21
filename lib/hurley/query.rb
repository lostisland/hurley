require "cgi"
require "forwardable"
require "stringio"

module Hurley
  class Query
    def self.default
      @default ||= Nested
    end

    def self.parse(raw_query)
      default.parse(raw_query)
    end

    def initialize(initial = nil)
      @hash = {}
      update(initial) if initial
    end

    extend Forwardable
    def_delegators(:@hash,
      :[], :[]=,
      :each,
      :keys,
      :size,
      :delete,
      :key?,
    )

    def subset_of?(url)
      query = url.respond_to?(:query) ? url.query : url
      @hash.keys.all? do |key|
        query[key] == @hash[key]
      end
    end

    def update(absolute)
      absolute.each do |key, value|
        @hash[key] = value unless key?(key)
      end
    end

    def parse_query(raw_query)
      raw_query.to_s.split(AMP).each do |pair|
        next if pair.empty?
        escaped_key, escaped_value = pair.split(EQ, 2)
        key = CGI.unescape(escaped_key)
        value = escaped_value ? CGI.unescape(escaped_value) : nil
        send(:decode_pair, key, value)
      end
    end

    def multipart?
      any_multipart?(@hash.values)
    end

    def to_query_string
      build_pairs.map!(&:to_s).join(AMP)
    end

    def to_form(options = nil)
      if multipart?
        boundary = (options || RequestOptions.new).boundary
        return MULTIPART_TYPE % boundary, to_io(boundary)
      else
        return FORM_TYPE, StringIO.new(to_query_string)
      end
    end

    alias to_s to_query_string

    def inspect
      "#<%s %s>" % [
        self.class.name,
        @hash.inspect,
      ]
    end

    def self.inherited(base)
      super
      class << base
        def parse(raw_query)
          q = new
          q.parse_query(raw_query)
          q
        end
      end
    end

    class Nested < self
      private

      def decode_pair(key, value)
        if key !~ END_BRACKET
          self[key] = value
          return
        end

        first_key = key[0, key.index(START_BRACKET)]
        hash_keys = [first_key, *key.scan(/\[([^\]]+)?\]/).map(&:first)]
        last_index = hash_keys.size - 1
        container = self
        hash_keys.each_with_index do |hash_key, index|
          if index < last_index
            if hash_keys[index+1]
              container = if hash_key
                container[hash_key] ||= {}
              else
                c = {}
                container << c
                container = c
              end
            else
              container = container[hash_key] ||= []
            end
          else
            if hash_key
              container[hash_key] = value
            else
              container << value
            end
          end
        end
      end

      def encode_array(pairs, key, escaped_key, value)
        encode_nested_value(pairs, key, escaped_key, value)
      end

      def encode_hash(pairs, key, escaped_key, value)
        value.each do |value_key, item|
          nested_key = "#{key}[#{value_key}]"
          nested_escaped_key = "#{escaped_key}%5B#{Url.escape_path(value_key)}%5D"
          encode_nested_value(pairs, nested_key, nested_escaped_key, item)
        end
      end

      def encode_nested_value(pairs, key, escaped_key, value)
        case value
        when Array
          arr_key = "#{key}#{EMPTY_BRACKET}"
          arr_escaped_key = escaped_key + EMPTY_ESCAPED_BRACKET
          value.each do |item|
            encode_nested_value(pairs, arr_key, arr_escaped_key, item)
          end
        when Hash
          value.each do |hash_key, hash_value|
            nested_key = "#{key}[#{hash_key}]"
            nested_escaped_key = "#{escaped_key}%5B#{Url.escape_path(hash_key)}%5D"
            encode_nested_value(pairs, nested_key, nested_escaped_key, hash_value)
          end
        else
          pairs << Pair.new(key, escaped_key, value)
        end
      end
    end

    class Flat < self
      private

      def decode_pair(key, value)
        self[key] = if key?(key)
          Array(self[key]) << value
        else
          value
        end
      end

      def encode_array(pairs, key, escaped_key, value)
        value.each do |item|
          pairs << Pair.new(key, escaped_key, item)
        end
      end
    end

    class Pair < Struct.new(:key, :escaped_key, :value)
      def to_s
        if value
          "#{escaped_key}=#{Url.escape_path(value)}"
        else
          escaped_key
        end
      end
    end

    # Private Hurley::Query methods

    private

    def any_multipart?(array)
      array.any? do |v|
        case v
        when Array then any_multipart?(v)
        when Hash then any_multipart?(v.values)
        else
          v.respond_to?(:read)
        end
      end
    end

    def to_io(boundary, part_headers = nil)
      parts = []

      part_headers ||= {}
      build_pairs.each do |pair|
        parts << Multipart::Part.new(boundary, pair.key, pair.value, part_headers[pair.key])
      end
      parts << Multipart::EpiloguePart.new(boundary)
      ios = []
      len = 0
      parts.each do |part|
        len += part.length
        ios << part.to_io
      end

      CompositeReadIO.new(len, *ios)
    end

    def build_pairs
      pairs = []
      @hash.each do |key, value|
        escaped_key = Url.escape_path(key)
        case value
        when nil then pairs << Pair.new(key, escaped_key, nil)
        when Array
          encode_array(pairs, key, escaped_key, value)
        when Hash
          encode_hash(pairs, key, escaped_key, value)
        else
          pairs << Pair.new(key, escaped_key, value)
        end
      end
      pairs
    end

    def encode_array(pairs, key, escaped_key, value)
      raise NotImplementedError
    end

    def encode_hash(pairs, key, escaped_key, value)
      raise NotImplementedError
    end

    AMP = "&".freeze
    EQ = "=".freeze
    EMPTY_BRACKET = "[]".freeze
    EMPTY_ESCAPED_BRACKET = "%5B%5D".freeze
    START_BRACKET = "[".freeze
    END_BRACKET = /\]\z/
    FORM_TYPE = "application/x-www-form-urlencoded".freeze
    MULTIPART_TYPE = "multipart/form-data; boundary=%s".freeze
  end
end
