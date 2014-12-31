require File.expand_path("../helper", __FILE__)

module Hurley
  class ConnectionTest < TestCase
    def test_get_full_url
      conn = Test::Connection.new
      conn.get "https://example.com/a/b" do |req|
        assert_equal "https://example.com/a/b?first=f&a=1&b=2", req.url.to_s
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
  end
end
