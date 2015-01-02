require File.expand_path("../helper", __FILE__)

module Hurley
  class UrlTest < TestCase
    def test_join
      errors = []

      {
        "https://example.com?v=1" => {
          "" => "https://example.com?v=1",
          "/" => "https://example.com/?v=1",
          "?a=1" => "https://example.com?a=1&v=1",
          "/?a=1" => "https://example.com/?a=1&v=1",
          "?v=2&a=1" => "https://example.com?v=2&a=1",
          "/?v=2&a=1" => "https://example.com/?v=2&a=1",
          "a" => "https://example.com/a?v=1",
          "a/" => "https://example.com/a/?v=1",
          "a?a=1" => "https://example.com/a?a=1&v=1",
          "a/?a=1" => "https://example.com/a/?a=1&v=1",
          "a?v=2&a=1" => "https://example.com/a?v=2&a=1",
          "a/?v=2&a=1" => "https://example.com/a/?v=2&a=1",
          "a/b" => "https://example.com/a/b?v=1",
          "a/b/" => "https://example.com/a/b/?v=1",
          "a/b?a=1" => "https://example.com/a/b?a=1&v=1",
          "a/b/?a=1" => "https://example.com/a/b/?a=1&v=1",
          "a/b?v=2&a=1" => "https://example.com/a/b?v=2&a=1",
          "a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
        },

        "https://example.com/?v=1" => {
          "" => "https://example.com/?v=1",
          "/" => "https://example.com/?v=1",
          "?a=1" => "https://example.com/?a=1&v=1",
          "/?a=1" => "https://example.com/?a=1&v=1",
          "?v=2&a=1" => "https://example.com/?v=2&a=1",
          "/?v=2&a=1" => "https://example.com/?v=2&a=1",
          "a" => "https://example.com/a?v=1",
          "a/" => "https://example.com/a/?v=1",
          "a?a=1" => "https://example.com/a?a=1&v=1",
          "a/?a=1" => "https://example.com/a/?a=1&v=1",
          "a?v=2&a=1" => "https://example.com/a?v=2&a=1",
          "a/?v=2&a=1" => "https://example.com/a/?v=2&a=1",
          "a/b" => "https://example.com/a/b?v=1",
          "a/b/" => "https://example.com/a/b/?v=1",
          "a/b?a=1" => "https://example.com/a/b?a=1&v=1",
          "a/b/?a=1" => "https://example.com/a/b/?a=1&v=1",
          "a/b?v=2&a=1" => "https://example.com/a/b?v=2&a=1",
          "a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
        },

        "https://example.com/a?v=1" => {
          "" => "https://example.com/a?v=1",
          "/" => "https://example.com/?v=1",
          "?a=1" => "https://example.com/a?a=1&v=1",
          "/?a=1" => "https://example.com/?a=1&v=1",
          "?v=2&a=1" => "https://example.com/a?v=2&a=1",
          "/?v=2&a=1" => "https://example.com/?v=2&a=1",
          "/a" => "https://example.com/a?v=1",
          "/a/" => "https://example.com/a/?v=1",
          "/a?a=1" => "https://example.com/a?a=1&v=1",
          "/a/?a=1" => "https://example.com/a/?a=1&v=1",
          "/a?v=2&a=1" => "https://example.com/a?v=2&a=1",
          "/a/?v=2&a=1" => "https://example.com/a/?v=2&a=1",
          "/a/b" => "https://example.com/a/b?v=1",
          "/a/b/" => "https://example.com/a/b/?v=1",
          "/a/b?a=1" => "https://example.com/a/b?a=1&v=1",
          "/a/b/?a=1" => "https://example.com/a/b/?a=1&v=1",
          "/a/b?v=2&a=1" => "https://example.com/a/b?v=2&a=1",
          "/a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
          "c" => "https://example.com/a/c?v=1",
          "c/" => "https://example.com/a/c/?v=1",
          "c?a=1" => "https://example.com/a/c?a=1&v=1",
          "c/?a=1" => "https://example.com/a/c/?a=1&v=1",
          "c?v=2&a=1" => "https://example.com/a/c?v=2&a=1",
          "c/?v=2&a=1" => "https://example.com/a/c/?v=2&a=1",
          "/c" => "https://example.com/c?v=1",
          "/c/" => "https://example.com/c/?v=1",
          "/c?a=1" => "https://example.com/c?a=1&v=1",
          "/c/?a=1" => "https://example.com/c/?a=1&v=1",
          "/c?v=2&a=1" => "https://example.com/c?v=2&a=1",
          "/c/?v=2&a=1" => "https://example.com/c/?v=2&a=1",
        },

        "https://example.com/a/?v=1" => {
          "" => "https://example.com/a/?v=1",
          "/" => "https://example.com/?v=1",
          "?a=1" => "https://example.com/a/?a=1&v=1",
          "/?a=1" => "https://example.com/?a=1&v=1",
          "?v=2&a=1" => "https://example.com/a/?v=2&a=1",
          "/?v=2&a=1" => "https://example.com/?v=2&a=1",
          "/a" => "https://example.com/a?v=1",
          "/a/" => "https://example.com/a/?v=1",
          "/a?a=1" => "https://example.com/a?a=1&v=1",
          "/a/?a=1" => "https://example.com/a/?a=1&v=1",
          "/a?v=2&a=1" => "https://example.com/a?v=2&a=1",
          "/a/?v=2&a=1" => "https://example.com/a/?v=2&a=1",
          "/a/b" => "https://example.com/a/b?v=1",
          "/a/b/" => "https://example.com/a/b/?v=1",
          "/a/b?a=1" => "https://example.com/a/b?a=1&v=1",
          "/a/b/?a=1" => "https://example.com/a/b/?a=1&v=1",
          "/a/b?v=2&a=1" => "https://example.com/a/b?v=2&a=1",
          "/a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
          "c" => "https://example.com/a/c?v=1",
          "c/" => "https://example.com/a/c/?v=1",
          "c?a=1" => "https://example.com/a/c?a=1&v=1",
          "c/?a=1" => "https://example.com/a/c/?a=1&v=1",
          "c?v=2&a=1" => "https://example.com/a/c?v=2&a=1",
          "c/?v=2&a=1" => "https://example.com/a/c/?v=2&a=1",
          "/c" => "https://example.com/c?v=1",
          "/c/" => "https://example.com/c/?v=1",
          "/c?a=1" => "https://example.com/c?a=1&v=1",
          "/c/?a=1" => "https://example.com/c/?a=1&v=1",
          "/c?v=2&a=1" => "https://example.com/c?v=2&a=1",
          "/c/?v=2&a=1" => "https://example.com/c/?v=2&a=1",
        },
      }.each do |endpoint, tests|
        absolute = Url.parse(endpoint)
        tests.each do |input, expected|
          actual = Url.join(absolute, input).to_s
          if actual != expected
            errors << "#{endpoint.inspect} + #{input.inspect} = #{actual.inspect}"
          end
        end
      end

      if errors.any?
        fail "\n" + errors.join("\n")
      end
    end

    def test_escape
      {
        "abc" => "abc",
        "a/b" => "a%2Fb",
        "a b" => "a%20b",
        "a+b" => "a%2Bb",
        "a +b" => "a%20%2Bb",
        "a&b" => "a%26b",
        "a=b" => "a%3Db",
        "a;b" => "a%3Bb",
        "a?b" => "a%3Fb",
      }.each do |input, expected|
        assert_equal expected, Url.escape_path(input)
      end
    end

    def test_escape_paths
      assert_equal "a%20%2B%201/b%3B1", Url.escape_paths("a + 1", "b;1")
    end

    def test_parse_empty
      u = Url.parse(nil)
      assert_nil u.scheme
      assert_nil u.host
      assert_nil u.port
      assert_equal "", u.path
      assert_equal "", u.to_s
    end

    def test_parse_only_path
      u = Url.parse("/foo")
      assert_nil u.scheme
      assert_nil u.host
      assert_nil u.port
      assert_equal "/foo", u.path
      assert_equal "/foo", u.to_s
    end

    def test_parse_url_with_host
      u = Url.parse("https://example.com?a=1")
      assert_equal "https", u.scheme
      assert_equal "example.com", u.host
      assert_equal 443, u.port
      assert_equal "", u.path
      assert_equal "a=1", u.raw_query
      assert_equal %w(a), u.query.keys
      assert_equal "1", u.query["a"]
      assert_equal "https://example.com?a=1", u.to_s
    end

    def test_parse_url_with_slash
      u = Url.parse("https://example.com/?a=1")
      assert_equal "https", u.scheme
      assert_equal "example.com", u.host
      assert_equal 443, u.port
      assert_equal "/", u.path
      assert_equal "a=1", u.raw_query
      assert_equal %w(a), u.query.keys
      assert_equal "1", u.query["a"]
      assert_equal "https://example.com/?a=1", u.to_s
    end

    def test_parse_url_with_path
      u = Url.parse("https://example.com/foo?a=1")
      assert_equal "https", u.scheme
      assert_equal "example.com", u.host
      assert_equal 443, u.port
      assert_equal "/foo", u.path
      assert_equal "a=1", u.raw_query
      assert_equal %w(a), u.query.keys
      assert_equal "1", u.query["a"]
      assert_equal "https://example.com/foo?a=1", u.to_s
    end
  end
end
