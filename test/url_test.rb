require File.expand_path("../helper", __FILE__)

module Hurley
  class UrlTest < TestCase
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

    def test_parse_url
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

    def test_joining_with_full_url
      u = Url.parse("https://example.com/foo?a=1")

      {
        ""                                    => "https://example.com/foo?a=1",
        "bar"                                 => "https://example.com/foo/bar?a=1",
        "bar?a=1"                             => "https://example.com/foo/bar?a=1",
        "bar?a=1&b=2"                         => "https://example.com/foo/bar?a=1&b=2",
        "/foo?a=1&b=2"                        => "https://example.com/foo?a=1&b=2",
        "/foo/bar?a=1&b=2"                    => "https://example.com/foo/bar?a=1&b=2",
        "https://example.com/foo?b=2"         => "https://example.com/foo?b=2&a=1",
        "https://example.com/foo?a=1&b=2"     => "https://example.com/foo?a=1&b=2",
        "https://example.com/foo/bar?a=1&b=2" => "https://example.com/foo/bar?a=1&b=2",
      }.each do |input, expected|
        assert u.parent_of?(Url.parse(input)),
          "#{u.to_s.inspect} not parent of #{input.inspect}"

        assert_equal expected, Url.join(u, input).to_s
      end

      [
        "?a=2",
        "bar?a=2",
        "/",
        "/foo?a=2",
        "/food",
        "https://example.com/foo?a=2",
        "https://example.com/food",
        "http://example.com/foo?a=1",
        "https://example.com:9999/foo?a=1",
        "https://example2.com/foo?a=1",
      ].each do |input|
        assert !u.parent_of?(Url.parse(input)),
          "#{u.to_s.inspect} is parent of #{input.inspect}"

        assert_equal input, Url.join(nil, input).to_s
      end
    end

    def test_joining_with_empty_url
      u = Url.parse(nil)

      [
        "",
        "/",
        "/foo?a=1",
        "https://example.com/foo",
        "https://example.com/foo?a=1",
      ].each do |input|
        assert !u.parent_of?(Url.parse(input)),
          "#{u.to_s.inspect} is parent of #{input.inspect}"

        assert_equal input, Url.join(nil, input).to_s
      end
    end
  end
end
