require File.expand_path("../helper", __FILE__)

module Hurley
  class ConnectionTest < TestCase
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

      root_tests = {
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
      }

      foo_tests = {
        "/foo" => "/foo",
        "/foo/" => "/foo",
        "/foo/bar" => "/foo/bar",
        "/foo/bar/" => "/foo/bar",
        "/baz" => "/baz",
        "/baz/" => "/baz",
      }

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

    def test_get_url_with_host_and_handler_path
      conn = Test.new
      conn.get "/a/b" do |req|
        assert_equal "https://example.com/a/b?first=f&a=1&b=2", req.url.to_s
        assert_equal Hurley::USER_AGENT, req.header[:user_agent]
        assert_equal "1", req.header["Global"]
        assert_equal "2!", req.header["Override"]
        assert_equal "3", req.header["Custom"]

        [200, {"Content-Type" => "text/plain"}, "ok"]
      end

      c = Client.new "https://example.com?a=1"
      c.header["Global"] = "1"
      c.header["Override"] = "2"
      c.connection = conn

      res = c.get "a/b?first=f" do |req|
        req.header["Override"] = "2!"
        req.header["Custom"] = "3"
        req.url.query["b"] = 2
      end

      assert_equal 200, res.status_code
      assert_equal "text/plain", res.header["Content-Type"]
      assert_equal "ok", res.body
      assert conn.all_run?
    end

    def test_get_url_with_slash_and_handler_path
      conn = Test.new
      conn.get "/a/b" do |req|
        assert_equal "https://example.com/a/b?first=f&a=1&b=2", req.url.to_s
        assert_equal Hurley::USER_AGENT, req.header[:user_agent]
        assert_equal "1", req.header["Global"]
        assert_equal "2!", req.header["Override"]
        assert_equal "3", req.header["Custom"]

        [200, {"Content-Type" => "text/plain"}, "ok"]
      end

      c = Client.new "https://example.com/?a=1"
      c.header["Global"] = "1"
      c.header["Override"] = "2"
      c.connection = conn

      res = c.get "a/b?first=f" do |req|
        req.header["Override"] = "2!"
        req.header["Custom"] = "3"
        req.url.query["b"] = 2
      end

      assert_equal 200, res.status_code
      assert_equal "text/plain", res.header["Content-Type"]
      assert_equal "ok", res.body
      assert conn.all_run?
    end

    def test_get_url_with_path_and_handler_path
      conn = Test.new
      conn.get "/a/b" do |req|
        assert_equal "https://example.com/a/b?first=f&a=1&b=2", req.url.to_s
        assert_equal Hurley::USER_AGENT, req.header[:user_agent]
        assert_equal "1", req.header["Global"]
        assert_equal "2!", req.header["Override"]
        assert_equal "3", req.header["Custom"]

        [200, {"Content-Type" => "text/plain"}, "ok"]
      end

      c = Client.new "https://example.com/a?a=1"
      c.header["Global"] = "1"
      c.header["Override"] = "2"
      c.connection = conn

      res = c.get "b?first=f" do |req|
        req.header["Override"] = "2!"
        req.header["Custom"] = "3"
        req.url.query["b"] = 2
      end

      assert_equal 200, res.status_code
      assert_equal "text/plain", res.header["Content-Type"]
      assert_equal "ok", res.body
      assert conn.all_run?
    end

    def test_get_url_with_path_and_handler_url
      conn = Test.new
      conn.get "https://example.com/a/b" do |req|
        assert_equal "https://example.com/a/b?first=f&a=1&b=2", req.url.to_s
        assert_equal Hurley::USER_AGENT, req.header[:user_agent]
        assert_equal "1", req.header["Global"]
        assert_equal "2!", req.header["Override"]
        assert_equal "3", req.header["Custom"]

        [200, {"Content-Type" => "text/plain"}, "ok"]
      end

      c = Client.new "https://example.com/a?a=1"
      c.header["Global"] = "1"
      c.header["Override"] = "2"
      c.connection = conn

      res = c.get "b?first=f" do |req|
        req.header["Override"] = "2!"
        req.header["Custom"] = "3"
        req.url.query["b"] = 2
      end

      assert_equal 200, res.status_code
      assert_equal "text/plain", res.header["Content-Type"]
      assert_equal "ok", res.body
      assert conn.all_run?
    end

    def test_get_url_with_path_and_different_handler_scheme
      conn = Test.new
      conn.get "http://example.com/a/b" do |req|
        [500, {}, "wat"]
      end

      c = Client.new "https://example.com/a?a=1"
      c.header["Global"] = "1"
      c.header["Override"] = "2"
      c.connection = conn

      assert_equal 404, c.get("b?first=f").status_code
    end

    def test_get_url_with_path_and_different_handler_port
      conn = Test.new
      conn.get "https://example.com:8080/a/b" do |req|
        [500, {}, "wat"]
      end

      c = Client.new "https://example.com/a?a=1"
      c.header["Global"] = "1"
      c.header["Override"] = "2"
      c.connection = conn

      assert_equal 404, c.get("b?first=f").status_code
    end

    def test_get_url_with_path_and_different_handler_host
      conn = Test.new
      conn.get "https://other.example.com/a/b" do |req|
        [500, {}, "wat"]
      end

      c = Client.new "https://example.com/a?a=1"
      c.header["Global"] = "1"
      c.header["Override"] = "2"
      c.connection = conn

      assert_equal 404, c.get("b?first=f").status_code
    end

    def test_get_url_with_custom_on_body
      conn = Test.new
      conn.get "/stream" do |req|
        [200, {}, "stream"]
      end

      c = Client.new "https://example.com"
      c.connection = conn

      chunks = []
      res = c.get("stream") do |req|
        req.on_body do |res, chunk|
          chunks << chunk
        end
      end

      assert_equal 200, res.status_code
      assert_nil res.body
      assert_equal %w(stream), chunks
    end

    def test_get_url_with_streaming_response
      conn = Test.new
      conn.get "/stream" do |req|
        [200, {}, %w(st r ea m!)]
      end

      c = Client.new "https://example.com"
      c.connection = conn

      res = c.get("stream")
      assert_equal 200, res.status_code
      assert_equal "stream!", res.body
    end

    def test_get_url_with_streaming_response_and_custom_on_body
      conn = Test.new
      conn.get "/stream" do |req|
        [200, {}, %w(st r ea m!)]
      end

      c = Client.new "https://example.com"
      c.connection = conn

      chunks = []
      res = c.get("stream") do |req|
        req.on_body do |res, chunk|
          chunks << chunk
        end
      end

      assert_equal 200, res.status_code
      assert_nil res.body
      assert_equal %w(st r ea m!), chunks
    end

    def test_get_url_with_streaming_response_with_correct_status
      conn = Test.new
      conn.get "/stream" do |req|
        [200, {}, %w(st r ea m!)]
      end

      c = Client.new "https://example.com"
      c.connection = conn

      chunks = []
      res = c.get("stream") do |req|
        req.on_body 201, 200 do |res, chunk|
          chunks << chunk
        end
      end

      assert_equal 200, res.status_code
      assert_nil res.body
      assert_equal %w(st r ea m!), chunks
    end

    def test_get_url_with_streaming_response_with_wrong_status
      conn = Test.new
      conn.get "/stream" do |req|
        [200, {}, %w(st r ea m!)]
      end

      c = Client.new "https://example.com"
      c.connection = conn

      chunks = []
      res = c.get("stream") do |req|
        req.on_body 201 do |res, chunk|
          chunks << chunk
        end
      end

      assert_equal 200, res.status_code
      assert_equal "stream!", res.body
      assert_equal [], chunks
    end
  end
end
