require "cgi"
require "forwardable"

module Hurley
  class Query
    def self.parser
      @parser ||= Hurley.mutex { parser_for(nil) }
    end

    def self.parser=(new_parser)
      @parser = parser_for(new_parser)
    end

    def self.parser_for(new_parser)
      if new_parser.respond_to?(:call)
        new_parser
      elsif PARSERS.key?(new_parser)
        PARSERS[new_parser]
      elsif new_parser.nil?
        PARSERS[:nested]
      else
        raise ArgumentError, "#{name} parser should respond to #call(raw_query) or be one of #{PARSERS.keys.inspect}: #{new_parser.inspect}"
      end
    end

    def self.parse(raw_query)
      parser.call(raw_query)
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
        escaped_key, escaped_value = pair.split(EQ, 2)
        key = CGI.unescape(escaped_key)
        value = escaped_value ? CGI.unescape(escaped_value) : nil
        send(:decode_pair, key, value)
      end
    end

    def to_s
      pairs = []
      @hash.each do |key, value|
        escaped_key = Url.escape_path(key)
        case value
        when nil then pairs << escaped_key
        when Array
          encode_array(pairs, escaped_key, value)
        when Hash
          encode_hash(pairs, escaped_key, value)
        else
          pairs << "#{escaped_key}=#{Url.escape_path(value)}"
        end
      end
      pairs.join(AMP)
    end

    def inspect
      "#<%s %s>" % [
        self.class.name,
        @hash.inspect,
      ]
    end

    private

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

    def encode_array(pairs, escaped_key, value)
      raise NotImplementedError
    end

    def encode_hash(pairs, escaped_key, value)
      raise NotImplementedError
    end

    AMP = "&".freeze
    EQ = "=".freeze
    EMPTY_BRACKET = "[]".freeze
    START_BRACKET = "[".freeze
    END_BRACKET = /\]\z/

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

      def encode_array(pairs, escaped_key, value)
        encode_nested_value(pairs, escaped_key, value)
      end

      def encode_hash(pairs, escaped_key, value)
        value.each do |value_key, item|
          encode_nested_value(pairs, "#{escaped_key}[#{Url.escape_path(value_key)}]", item)
        end
      end

      def encode_nested_value(pairs, escaped_key, value)
        case value
        when Array
          arr_key = escaped_key + EMPTY_BRACKET
          value.each do |item|
            encode_nested_value(pairs, arr_key, item)
          end
        when Hash
          value.each do |hash_key, hash_value|
            encode_nested_value(pairs, "#{escaped_key}[#{Url.escape_path(hash_key)}]", hash_value)
          end
        else
          pairs << "#{escaped_key}=#{Url.escape_path(value)}"
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

      def encode_array(pairs, escaped_key, value)
        value.each do |item|
          pairs << "#{escaped_key}=#{Url.escape_path(item)}"
        end
      end
    end

    PARSERS = {
      :nested => Nested.method(:parse),
      :flat => Flat.method(:parse),
    }
  end
end
