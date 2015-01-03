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

    def test_integration_default_headers
      headers = [:content_type, :content_length, :transfer_encoding]
      c = Client.new "https://example.com"
      c.connection = Test.new do |test|
        [:get, :put, :post, :patch, :options, :delete].each do |verb|
          test.send(verb, "/a") do |req|
            body = if !req.body
              :-
            elsif req.body.respond_to?(:path)
              req.body.path
            else
              req.body_io.read
            end
            [200, {}, headers.map { |h| req.header[h] || "NONE" }.join(",") + " #{body}"]
          end
        end
      end

      errors = []
      tests = {}
      file_size = File.size(__FILE__)

      # IO-like object without #size/#length
      fake_reader = Object.new
      def fake_reader.read(*args)
        "READ"
      end

      # test defaults with non-body requests
      [:get, :patch, :options, :delete].each do |verb|
        tests.update(
          lambda {
            c.send(verb, "a")
          } => "NONE,NONE,NONE -",

          lambda {
            c.send(verb, "a") { |r| r.body ="ABC" }
          } => "application/octet-stream,3,NONE ABC",

          lambda {
            c.send(verb, "a") do |r|
              r.header[:content_type] = "text/plain"
              r.body = "ABC"
            end
          } => "text/plain,3,NONE ABC",
        )
      end

      # these http verbs need a body
      [:post, :put].each do |verb|
        tests.update(
          # RAW BODY TESTS

          lambda {
            c.send(verb, "a")
          } => "NONE,0,NONE -",

          lambda {
            c.send(verb, "a") do |r|
              r.body = "abc"
            end
          } => "application/octet-stream,3,NONE abc",

          lambda {
            c.send(verb, "a") do |r|
              r.header[:content_type] = "text/plain"
              r.body = "abc"
            end
          } => "text/plain,3,NONE abc",

          # FILE TESTS

          lambda {
            c.send(verb, "a") do |r|
              r.body = File.new(__FILE__)
            end
          } => "application/octet-stream,#{file_size},NONE #{__FILE__}",

          lambda {
            c.send(verb, "a") do |r|
              r.header[:content_type] = "text/plain"
              r.body = File.new(__FILE__)
            end
          } => "text/plain,#{file_size},NONE #{__FILE__}",

          # GENERIC IO TESTS

          lambda {
            c.send(verb, "a") do |r|
              r.body = fake_reader
            end
          } => "application/octet-stream,NONE,chunked READ",

          lambda {
            c.send(verb, "a") do |r|
              r.header[:content_type] = "text/plain"
              r.body = fake_reader
            end
          } => "text/plain,NONE,chunked READ",

          lambda {
            c.send(verb, "a") do |r|
              r.header[:content_length] = 4
              r.body = fake_reader
            end
          } => "application/octet-stream,4,NONE READ",

          lambda {
            c.send(verb, "a") do |r|
              r.header[:content_length] = 4
              r.header[:content_type] = "text/plain"
              r.body = fake_reader
            end
          } => "text/plain,4,NONE READ",
        )
      end

      tests.each do |req_block, expected|
        res = req_block.call
        req = res.request
        if expected != res.body
          errors << "#{req.inspect} Expected #{expected.inspect}; Got #{res.body.inspect}"
        end
      end

      if errors.any?
        fail "\n" + errors.join("\n")
      end
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
