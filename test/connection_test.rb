require File.expand_path("../helper", __FILE__)

module Hurley
  class ConnectionTest < TestCase
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

      req = c.request :get, "a/b?first=f"
      req.header["Override"] = "2!"
      req.header["Custom"] = "3"
      req.url.query["b"] = 2
      res = req.call
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

      req = c.request :get, "a/b?first=f"
      req.header["Override"] = "2!"
      req.header["Custom"] = "3"
      req.url.query["b"] = 2
      res = req.call
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

      req = c.request :get, "b?first=f"
      req.header["Override"] = "2!"
      req.header["Custom"] = "3"
      req.url.query["b"] = 2
      res = req.call
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

      req = c.request :get, "b?first=f"
      req.header["Override"] = "2!"
      req.header["Custom"] = "3"
      req.url.query["b"] = 2
      res = req.call
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

      assert_equal 404, c.request!(:get, "b?first=f").status_code
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

      assert_equal 404, c.request!(:get, "b?first=f").status_code
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

      assert_equal 404, c.request!(:get, "b?first=f").status_code
    end

    def test_get_url_with_custom_on_body
      conn = Test.new
      conn.get "/stream" do |req|
        [200, {}, "stream"]
      end

      c = Client.new "https://example.com"
      c.connection = conn

      req = c.request(:get, "stream")
      chunks = []

      req.on_body do |chunk|
        chunks << chunk
      end

      res = req.call
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

      res = c.request!(:get, "stream")
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

      req = c.request(:get, "stream")
      chunks = []

      req.on_body do |chunk|
        chunks << chunk
      end

      res = req.call
      assert_equal 200, res.status_code
      assert_nil res.body
      assert_equal %w(st r ea m!), chunks
    end
  end
end
