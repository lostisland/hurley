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

    def test_sets_before_callbacks
      c = Client.new nil
      c.before_call(:first) { |r| 1 }
      c.before_call { |r| 2 }
      c.before_call NamedCallback.new(:third, lambda { |r| 3 })

      assert_equal [:first, :undefined, :third], c.before_callbacks.map(&:name)
      assert_equal [1,2,3], c.before_callbacks.inject([]) { |list, cb| list << cb.call(nil) }
    end

    def test_sets_after_callbacks
      c = Client.new nil
      c.after_call(:first) { |r| 1 }
      c.after_call { |r| 2 }
      c.after_call NamedCallback.new(:third, lambda { |r| 3 })

      assert_equal [:first, :undefined, :third], c.after_callbacks.map(&:name)
      assert_equal [1,2,3], c.after_callbacks.inject([]) { |list, cb| list << cb.call(nil) }
    end
  end
end
