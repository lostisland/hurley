require File.expand_path("../helper", __FILE__)

module Hurley
  class IntegrationTest < TestCase
    def test_verbs
      verbs = [:head, :get, :put, :post, :delete, :options]
      client = Client.new "https://example.com"
      client.connection = Test.new do |t|
        verbs.each do |verb|
          t.handle(verb, "/a") do |req|
            [200, {}, verb.inspect]
          end
        end
      end

      errors = []

      verbs.each do |verb|
        res = client.send(verb, "/a")
        if res.body != verb.inspect
          errors << "#{verb} = #{res.status_code} / #{res.body}"
        end
      end

      if errors.any?
        fail "\n" + errors.join("\n")
      end
    end

    def test_url_joining
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

    def test_headers
      client = Client.new "https://example.com"
      client.header["Client"] = "1"
      client.header["Override"] = "1"
      client.connection = Test.new do |t|
        t.get("/a") do |req|
          output = []
          req.header.each do |key, value|
            output << "#{key}:#{value}"
          end
          [200, {}, output.join("\n")]
        end
      end

      res = client.get("/a") do |req|
        req.header["Request"] = "2"
        req.header["Override"] = "2"
      end

      assert_equal 200, res.status_code
      assert_equal "User-Agent:Hurley v0.1\nClient:1\nOverride:2\nRequest:2", res.body
    end

    def test_before_callback
      c = Client.new "https://example.com"
      c.connection = Test.new do |test|
        test.post "/a" do |req|
          assert_equal "BOOYA", req.body
          [200, {}, "meh"]
        end
      end

      c.before_call do |req|
        req.body = req.body.to_s.upcase
      end

      res = c.post "a" do |req|
        req.body = "booya"
      end

      assert_equal 200, res.status_code
      assert c.connection.all_run?
    end

    def test_after_callback
      c = Client.new "https://example.com"
      c.connection = Test.new do |test|
        test.get "/a" do |req|
          [200, {}, "meh"]
        end
      end

      c.after_call do |res|
        res.body = res.body.to_s.upcase
      end

      res = c.get "a"

      assert_equal 200, res.status_code
      assert_equal "MEH", res.body
      assert c.connection.all_run?
    end
  end
end
