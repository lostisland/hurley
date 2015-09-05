require File.expand_path("../helper", __FILE__)

module Hurley
  class TestTest < TestCase

    def setup
      @stubs = Test.new do |stub|
        stub.get "/a/verboten" do |req|
          [403, {}, ""]
        end

        stub.get("/a", expires: false) do |req|
          output = %w(fee fi fo fum)
          [200, {"Content-Length" => "13"}, output.join("\n")]
        end

        # forces the /a stub above to expire
        stub.get("/a") do |req|
          [200, {"Content-Length" => "4"}, "last"]
        end

        stub.get("/expires", expires: true) do |req|
          [200, {}, "last"]
        end

        # different verb, does not expire
        stub.post("/expires") do |req|
          [200, {}, "ok"]
        end
      end

      @client = Client.new do |c|
        c.connection = @stubs
      end
    end

    def test_matches_most_specific_handler
      res = @client.get("/a")
      assert_equal 200, res.status_code

      res = @client.get("/a/verboten")
      assert_equal 403, res.status_code
    end

    def test_returns_404_if_no_handler_found
      res = @client.get("/a")
      assert_equal 200, res.status_code

      res = @client.get("/b")
      assert_equal 404, res.status_code
    end

    def test_get_expiring_stub
      res = @client.get("/a")
      assert_equal 200, res.status_code
      assert_equal "fee\nfi\nfo\nfum", res.body

      res = @client.get("/a")
      assert_equal 200, res.status_code
      assert_equal "last", res.body

      res = @client.get("/a")
      assert_equal 404, res.status_code
    end

    def test_head_expiring_stub
      res = @client.head("/a")
      assert_equal 200, res.status_code
      assert_equal "13", res.header[:content_length]

      res = @client.get("/a")
      assert_equal 200, res.status_code
      assert_equal "4", res.header[:content_length]

      res = @client.get("/a")
      assert_equal 404, res.status_code
    end

    def test_matches_explicitly_expiring_stub
      res = @client.get("/expires")
      assert_equal 200, res.status_code
      assert_equal "last", res.body

      res = @client.get("/expires")
      assert_equal 404, res.status_code
    end

    def test_matches_expiring_url_with_different_verb
      res = @client.post("/expires")
      assert_equal 200, res.status_code
      assert_equal "ok", res.body

      res = @client.post("/expires")
      assert_equal 200, res.status_code
      assert_equal "ok", res.body
    end
  end
end
