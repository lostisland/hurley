require File.expand_path("../helper", __FILE__)

module Hurley
  class ClientTest < TestCase
    def test_parses_endpoint
      c = Client.new "https://example.com/a?a=1"
      assert_equal "https", c.scheme
      assert_equal "example.com", c.host
      assert_equal "/a", c.url.path
    end

    def test_builds_request
      c = Client.new "https://example.com/a?a=1"
      c.header["Accept"] = "*"

      req = c.request :get, "b"
      assert_equal "*", req.header["Accept"]

      url = req.url
      assert_equal "https://example.com/a/b?a=1", url.to_s
    end
  end
end
