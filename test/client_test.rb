require File.expand_path("../helper", __FILE__)

module Hurley
  class ClientTest < TestCase
    def test_integration_verbs
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

    def test_integration_before_callback
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

    def test_integration_after_callback
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
