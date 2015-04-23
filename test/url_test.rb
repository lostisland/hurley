require File.expand_path("../helper", __FILE__)

module Hurley
  class UrlTest < TestCase
    def test_integration_join
      test = Test.new

      ["/foo/bar", "/foo", "/baz"].each do |path|
        test.get("http://example.com" + path) do |req|
          [200, {}, "#{path} http #{req.url.raw_query}".strip]
        end

        test.get("https://sub.example.com" + path) do |req|
          [200, {}, "#{path} sub #{req.url.raw_query}".strip]
        end

        test.get(path + "?v=1") do |req|
          [200, {}, "#{path} v1 #{req.url.raw_query}".strip]
        end

        test.get(path + "?v=2") do |req|
          [200, {}, "#{path} v2 #{req.url.raw_query}".strip]
        end

        test.get(path) do |req|
          [200, {}, "#{path} #{req.url.raw_query}".strip]
        end

        test.get("https://example.com" + path) do |req|
          [500, {}, "unreachable"]
        end
      end

      errors = []

      extra_tests = {
        "http://example.com/foo" => "/foo http",
        "http://example.com/foo/bar" => "/foo/bar http",
        "http://example.com/baz" => "/baz http",

        "https://sub.example.com/foo" => "/foo sub",
        "https://sub.example.com/foo/bar" => "/foo/bar sub",
        "https://sub.example.com/baz" => "/baz sub",
      }

      root_tests = extra_tests.merge(
        "/foo" => "/foo",
        "/foo/" => "/foo",
        "/foo/bar" => "/foo/bar",
        "/foo/bar/" => "/foo/bar",
        "/baz" => "/baz",
        "/baz/" => "/baz",
        "foo" => "/foo",
        "foo/" => "/foo",
        "foo/bar" => "/foo/bar",
        "foo/bar/" => "/foo/bar",
        "baz" => "/baz",
        "baz/" => "/baz",

        # v1
        "/foo?v=1" => "/foo v1 v=1",
        "/foo/?v=1" => "/foo v1 v=1",
        "/foo/bar?v=1" => "/foo/bar v1 v=1",
        "/foo/bar/?v=1" => "/foo/bar v1 v=1",
        "/baz?v=1" => "/baz v1 v=1",
        "/baz/?v=1" => "/baz v1 v=1",
        "foo?v=1" => "/foo v1 v=1",
        "foo/?v=1" => "/foo v1 v=1",
        "foo/bar?v=1" => "/foo/bar v1 v=1",
        "foo/bar/?v=1" => "/foo/bar v1 v=1",
        "baz?v=1" => "/baz v1 v=1",
        "baz/?v=1" => "/baz v1 v=1",

        # v2
        "/foo?v=2" => "/foo v2 v=2",
        "/foo/?v=2" => "/foo v2 v=2",
        "/foo/bar?v=2" => "/foo/bar v2 v=2",
        "/foo/bar/?v=2" => "/foo/bar v2 v=2",
        "/baz?v=2" => "/baz v2 v=2",
        "/baz/?v=2" => "/baz v2 v=2",
        "foo?v=2" => "/foo v2 v=2",
        "foo/?v=2" => "/foo v2 v=2",
        "foo/bar?v=2" => "/foo/bar v2 v=2",
        "foo/bar/?v=2" => "/foo/bar v2 v=2",
        "baz?v=2" => "/baz v2 v=2",
        "baz/?v=2" => "/baz v2 v=2",
      )

      foo_tests = extra_tests.merge(
        "" => "/foo",
        "bar" => "/foo/bar",
        "bar/" => "/foo/bar",
        "/foo" => "/foo",
        "/foo/" => "/foo",
        "/foo/bar" => "/foo/bar",
        "/foo/bar/" => "/foo/bar",
        "/baz" => "/baz",
        "/baz/" => "/baz",
      )

      {
        "https://example.com" => root_tests,
        "https://example.com/" => root_tests,
        "https://example.com/foo" => foo_tests,
        "https://example.com/foo/" => foo_tests,
      }.each do |endpoint, requests|
        cli = Client.new(endpoint)
        cli.connection = test

        requests.each do |path, expected|
          res = cli.get(path)
          if res.body != expected
            errors << "#{endpoint} + #{path} == #{res.request.url.inspect}"
            errors << "  #{expected.inspect} != #{res.body.inspect}"
          end
        end
      end

      if errors.any?
        fail "\n" + errors.join("\n")
      end
    end

    def test_integration_basic_auth
      cli = Client.new "http://a:b@c.com/d"
      cli.connection = Test.new do |t|
        t.get "/d/e" do |req|
          token = req.header[:authorization].split(" ").last
          [200, {}, Base64.decode64(token)]
        end
      end

      req = cli.request :get, "e"
      res = cli.call req

      assert_equal 200, res.status_code
      assert_equal "a:b", res.body
    end

    def test_join
      errors = []

      {
        "https://example.com?v=1" => {
          ""             => "https://example.com?v=1",
          "/"            => "https://example.com/?v=1",
          "?a=1"         => "https://example.com?a=1&v=1",
          "/?a=1"        => "https://example.com/?a=1&v=1",
          "?v=2&a=1"     => "https://example.com?v=2&a=1",
          "/?v=2&a=1"    => "https://example.com/?v=2&a=1",
          "a"            => "https://example.com/a?v=1",
          "a/"           => "https://example.com/a/?v=1",
          "a?a=1"        => "https://example.com/a?a=1&v=1",
          "a/?a=1"       => "https://example.com/a/?a=1&v=1",
          "a?v=2&a=1"    => "https://example.com/a?v=2&a=1",
          "a/?v=2&a=1"   => "https://example.com/a/?v=2&a=1",
          "a/b"          => "https://example.com/a/b?v=1",
          "a/b/"         => "https://example.com/a/b/?v=1",
          "a/b?a=1"      => "https://example.com/a/b?a=1&v=1",
          "a/b/?a=1"     => "https://example.com/a/b/?a=1&v=1",
          "a/b?v=2&a=1"  => "https://example.com/a/b?v=2&a=1",
          "a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
        },

        "https://example.com/?v=1" => {
          ""             => "https://example.com/?v=1",
          "/"            => "https://example.com/?v=1",
          "?a=1"         => "https://example.com/?a=1&v=1",
          "/?a=1"        => "https://example.com/?a=1&v=1",
          "?v=2&a=1"     => "https://example.com/?v=2&a=1",
          "/?v=2&a=1"    => "https://example.com/?v=2&a=1",
          "a"            => "https://example.com/a?v=1",
          "a/"           => "https://example.com/a/?v=1",
          "a?a=1"        => "https://example.com/a?a=1&v=1",
          "a/?a=1"       => "https://example.com/a/?a=1&v=1",
          "a?v=2&a=1"    => "https://example.com/a?v=2&a=1",
          "a/?v=2&a=1"   => "https://example.com/a/?v=2&a=1",
          "a/b"          => "https://example.com/a/b?v=1",
          "a/b/"         => "https://example.com/a/b/?v=1",
          "a/b?a=1"      => "https://example.com/a/b?a=1&v=1",
          "a/b/?a=1"     => "https://example.com/a/b/?a=1&v=1",
          "a/b?v=2&a=1"  => "https://example.com/a/b?v=2&a=1",
          "a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
        },

        "https://example.com/a?v=1" => {
          ""              => "https://example.com/a?v=1",
          "/"             => "https://example.com/?v=1",
          "?a=1"          => "https://example.com/a?a=1&v=1",
          "/?a=1"         => "https://example.com/?a=1&v=1",
          "?v=2&a=1"      => "https://example.com/a?v=2&a=1",
          "/?v=2&a=1"     => "https://example.com/?v=2&a=1",
          "/a"            => "https://example.com/a?v=1",
          "/a/"           => "https://example.com/a/?v=1",
          "/a?a=1"        => "https://example.com/a?a=1&v=1",
          "/a/?a=1"       => "https://example.com/a/?a=1&v=1",
          "/a?v=2&a=1"    => "https://example.com/a?v=2&a=1",
          "/a/?v=2&a=1"   => "https://example.com/a/?v=2&a=1",
          "/a/b"          => "https://example.com/a/b?v=1",
          "/a/b/"         => "https://example.com/a/b/?v=1",
          "/a/b?a=1"      => "https://example.com/a/b?a=1&v=1",
          "/a/b/?a=1"     => "https://example.com/a/b/?a=1&v=1",
          "/a/b?v=2&a=1"  => "https://example.com/a/b?v=2&a=1",
          "/a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
          "c"             => "https://example.com/a/c?v=1",
          "c/"            => "https://example.com/a/c/?v=1",
          "c?a=1"         => "https://example.com/a/c?a=1&v=1",
          "c/?a=1"        => "https://example.com/a/c/?a=1&v=1",
          "c?v=2&a=1"     => "https://example.com/a/c?v=2&a=1",
          "c/?v=2&a=1"    => "https://example.com/a/c/?v=2&a=1",
          "/c"            => "https://example.com/c?v=1",
          "/c/"           => "https://example.com/c/?v=1",
          "/c?a=1"        => "https://example.com/c?a=1&v=1",
          "/c/?a=1"       => "https://example.com/c/?a=1&v=1",
          "/c?v=2&a=1"    => "https://example.com/c?v=2&a=1",
          "/c/?v=2&a=1"   => "https://example.com/c/?v=2&a=1",
        },

        "https://example.com/a/?v=1" => {
          ""              => "https://example.com/a/?v=1",
          "/"             => "https://example.com/?v=1",
          "?a=1"          => "https://example.com/a/?a=1&v=1",
          "/?a=1"         => "https://example.com/?a=1&v=1",
          "?v=2&a=1"      => "https://example.com/a/?v=2&a=1",
          "/?v=2&a=1"     => "https://example.com/?v=2&a=1",
          "/a"            => "https://example.com/a?v=1",
          "/a/"           => "https://example.com/a/?v=1",
          "/a?a=1"        => "https://example.com/a?a=1&v=1",
          "/a/?a=1"       => "https://example.com/a/?a=1&v=1",
          "/a?v=2&a=1"    => "https://example.com/a?v=2&a=1",
          "/a/?v=2&a=1"   => "https://example.com/a/?v=2&a=1",
          "/a/b"          => "https://example.com/a/b?v=1",
          "/a/b/"         => "https://example.com/a/b/?v=1",
          "/a/b?a=1"      => "https://example.com/a/b?a=1&v=1",
          "/a/b/?a=1"     => "https://example.com/a/b/?a=1&v=1",
          "/a/b?v=2&a=1"  => "https://example.com/a/b?v=2&a=1",
          "/a/b/?v=2&a=1" => "https://example.com/a/b/?v=2&a=1",
          "c"             => "https://example.com/a/c?v=1",
          "c/"            => "https://example.com/a/c/?v=1",
          "c?a=1"         => "https://example.com/a/c?a=1&v=1",
          "c/?a=1"        => "https://example.com/a/c/?a=1&v=1",
          "c?v=2&a=1"     => "https://example.com/a/c?v=2&a=1",
          "c/?v=2&a=1"    => "https://example.com/a/c/?v=2&a=1",
          "/c"            => "https://example.com/c?v=1",
          "/c/"           => "https://example.com/c/?v=1",
          "/c?a=1"        => "https://example.com/c?a=1&v=1",
          "/c/?a=1"       => "https://example.com/c/?a=1&v=1",
          "/c?v=2&a=1"    => "https://example.com/c?v=2&a=1",
          "/c/?v=2&a=1"   => "https://example.com/c/?v=2&a=1",
        },

        "http://example.com" => {
          ""                         => "http://example.com",
          "/"                        => "http://example.com/",
          "https://example.com"      => "https://example.com",
          "https://example.com:8080" => "https://example.com:8080",
        },

        "http://example.com:8080" => {
          ""                         => "http://example.com:8080",
          "/"                        => "http://example.com:8080/",
          "https://example.com"      => "https://example.com",
          "https://example.com:8080" => "https://example.com:8080",
        },
      }.each do |endpoint, tests|
        absolute = Url.parse(endpoint)
        tests.each do |input, expected|
          actual = Url.join(absolute, input).to_s
          if actual != expected
            errors << "#{endpoint.inspect} + #{input.inspect} = #{actual.inspect}, not #{expected.inspect}"
          end
        end
      end

      if errors.any?
        fail "\n" + errors.join("\n")
      end
    end

    def test_escape
      {
        "abc"  => "abc",
        "a/b"  => "a%2Fb",
        "a b"  => "a%20b",
        "a+b"  => "a%2Bb",
        "a +b" => "a%20%2Bb",
        "a&b"  => "a%26b",
        "a=b"  => "a%3Db",
        "a;b"  => "a%3Bb",
        "a?b"  => "a%3Fb",
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
      assert_nil u.user
      assert_nil u.password
    end

    def test_parse_only_path
      u = Url.parse("/foo")
      assert_nil u.scheme
      assert_nil u.host
      assert_nil u.port
      assert_equal "/foo", u.path
      assert_equal "/foo", u.to_s
      assert_nil u.user
      assert_nil u.password
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
      assert_nil u.user
      assert_nil u.password
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
      assert_nil u.user
      assert_nil u.password
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
      assert_nil u.user
      assert_nil u.password
      assert_equal "https://example.com/foo?a=1", u.to_s
    end

    def test_parse_url_with_auth
      u = Url.parse("https://a:b%20c@example.com")
      assert_equal "https", u.scheme
      assert_equal "example.com", u.host
      assert_equal 443, u.port
      assert_equal "", u.path
      assert_equal "a", u.user
      assert_equal "b c", u.password
      assert_equal "https://example.com", u.to_s
    end

    def test_join_auth_url_with_url
      u = Url.join("http://a:b@c.com", "/path")
      assert_equal "a", u.user
      assert_equal "b", u.password
      assert_equal "http://c.com/path", u.to_s
    end

    def test_join_auth_url_with_url_of_same_host
      u = Url.join("http://a:b@c.com", "http://c.com/path")
      assert_equal "a", u.user
      assert_equal "b", u.password
      assert_equal "http://c.com/path", u.to_s
    end

    def test_join_auth_url_with_url_of_different_host
      u = Url.join("http://a:b@c.com", "http://d.com/path")
      assert_nil u.user
      assert_nil u.password
      assert_equal "http://d.com/path", u.to_s
    end

    def test_basic_auth_user_with_password
      u = Url.parse("http://a%20b:1%20%2B%202@foo.com")
      assert_equal "a b", u.user
      assert_equal "1 + 2", u.password
      assert_equal "Basic YSBiOjEgKyAy", u.basic_auth
    end

    def test_basic_auth_user_with_non_encoded_password
      u = Url.parse("http://a%20b:MxYut8Rj8tQi6%3DwNf.miTxf%3Eq49%3F%2Cf%40v" \
                    "QX8og3YT%3Fs.%5D8L3h9)@foo.com")
      assert_equal "a b", u.user
      assert_equal "MxYut8Rj8tQi6=wNf.miTxf>q49?,f@vQX8og3YT?s.]8L3h9)", u.password
      assert_equal "Basic YSBiOk14WXV0OFJqOHRRaTY9d05mLm1pVHhmPnE0OT8sZkB2UVg4b2czWVQ/cy5dOEwzaDkp", u.basic_auth
    end

    def test_basic_auth_user_without_password
      u = Url.parse("http://a%20b@foo.com")
      assert_equal "a b", u.user
      assert_nil u.password
      assert_equal "Basic YSBi", u.basic_auth
    end

    def test_join_url_with_auth_url
      u = Url.join("http://c.com/path", "http://a:b@c.com")
      assert_equal "a", u.user
      assert_equal "b", u.password
      assert_equal "http://c.com/path", u.to_s
    end

    def test_change_query_class
      u = Url.parse "http://a.com?b=c"
      u.query_class = Query::Nested

      assert_equal "b=c", u.raw_query
      assert_kind_of Query::Nested, u.query

      u.query["d"] = "f"
      u.query["a"] = [1,2]
      assert_equal "b=c&d=f&a%5B%5D=1&a%5B%5D=2", u.raw_query

      u.query_class = Query::Flat
      assert_kind_of Query::Flat, u.query
      assert_equal "b=c&d=f&a=1&a=2", u.raw_query
    end

    def test_url_parser
      expected = if ENV["HURLEY_ADDRESSABLE"]
        "Addressable::URI"
      else
        "URI::HTTPS"
      end

      assert_equal expected, Url.parse("https://example.com").instance_variable_get(:@parsed).class.name
    end
  end
end
