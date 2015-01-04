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

    def test_integration_with_query
      c = Client.new "https://example.com"
      c.connection = Test.new do |test|
        [:get, :options, :delete].each do |verb|
          test.send(verb, "/a") do |req|
            [200, {}, req.url.to_s]
          end
        end
      end

      errors = []
      prefix = "https://example.com/a"

      {
        nil => prefix,
        {:foo => :bar} => "#{prefix}?foo=bar",
      }.each do |input, expected|
        [:get, :options, :delete].each do |verb|
          res = c.send(verb, "a", input)
          if res.body != expected
            errors << "#{res.request.url.inspect} => #{expected.inspect} != #{res.body.inspect}"
          end
        end
      end

      if errors.any?
        fail "\n" + errors.join("\n")
      end
    end

    def test_integration_with_body
      c = Client.new "https://example.com"
      c.connection = Test.new do |test|
        [:post, :put, :patch].each do |verb|
          test.send(verb, "/form") do |req|
            [200, {}, "#{req.header[:content_type]}:#{req.body_io.read}"]
          end
        end

        [:post, :put, :patch].each do |verb|
          test.send(verb, "/multipart") do |req|
            m = Rack::Multipart.parse_multipart(
              "CONTENT_TYPE" => req.header[:content_type],
              "CONTENT_LENGTH" => req.header[:content_length],
              "rack.input" => req.body_io,
            )
            [200, {}, "#{req.header[:content_type]}:#{Array(m["a"]).join(",")}:#{m["h"].inspect}:#{m["file"][:tempfile].read}"]
          end
        end
      end

      errors = []

      flat_query = Query::Flat.new :a => [1,2]
      nested_query = Query::Nested.new :a => [1,2]

      {
        ["abc"] => "application/octet-stream:abc",
        ["abc", "text/plain"] => "text/plain:abc",
        [{:a => 1}] => "application/x-www-form-urlencoded:a=1",
        [flat_query] => "application/x-www-form-urlencoded:a=1&a=2",
        [nested_query] => "application/x-www-form-urlencoded:a%5B%5D=1&a%5B%5D=2",
        [flat_query, :form] => "form:a=1&a=2",
        [nested_query, :form] => "form:a%5B%5D=1&a%5B%5D=2",
      }.each do |args, expected|
        [:post, :put, :patch].each do |verb|
          res = c.send(verb, "form", *args)
          if res.body != expected
            errors << "#{verb} => #{expected.inspect} != #{res.body.inspect}"
          end
        end
      end

      multipart_tests = {}
      [:post, :put, :patch].each do |verb|
        nested_query = Query::Nested.new(:file => UploadIO.new(StringIO.new("ABC"), "text/plain"), :a => [1,2], :h => {:a => 1})
        flat_query = Query::Flat.new(:file => UploadIO.new(StringIO.new("ABC"), "text/plain"), :a => [3,4], :h => 0)
        hash_query = {:file => UploadIO.new(StringIO.new("ABC"), "text/plain"), :a => [5,6], :h => {:a => 1}}
        multipart_tests.update(
          c.send(verb, "multipart", nested_query) => %(:1,2:{"a"=>"1"}:ABC),
          c.send(verb, "multipart", flat_query) => %(:4:"0":ABC),
          c.send(verb, "multipart", hash_query) => %(:5,6:{"a"=>"1"}:ABC),
        )
      end

      multipart_tests.each do |res, expected|
        if res.body !~ %r{\Amultipart/form-data; boundary=Hurley-(\w+):}
          errors << "#{res.request.verb} multipart (#{expected[1..-1]}) bad type: #{res.body}"
        end

        if !res.body.end_with?(expected)
          errors << "#{res.request.verb} multipart (#{expected[1..-1]}) bad body: #{res.body}"
        end
      end

      if errors.any?
        fail "\n" + errors.join("\n")
      end
    end

    def test_integration_follow_get_redirect
      statuses = [301, 302, 303]

      c = Client.new "http://example.com?o=1"
      c.request_options.redirection_limit = 0
      c.connection = Test.new do |t|
        statuses.each do |st|
          t.get "/#{st}/host/2" do |req|
            [st, {"Location" => "http://example.com/#{st}/host/1"}, nil]
          end

          t.get "/#{st}/host/1" do |req|
            [st, {"Location" => "http://example.com/#{st}/host/0"}, nil]
          end

          t.get "/#{st}/host/0" do |req|
            [200, {}, "ok"]
          end

          t.post "/#{st}/host" do |req|
            [st, {"Location" => "http://example.com/#{st}/host/2?o=2"}, nil]
          end

          t.get "/#{st}/path/2" do |req|
            [st, {"Location" => "/#{st}/path/1"}, nil]
          end

          t.get "/#{st}/path/1" do |req|
            [st, {"Location" => "/#{st}/path/0"}, nil]
          end

          t.get "/#{st}/path/0" do |req|
            [200, {}, "ok"]
          end

          t.post "/#{st}/path" do |req|
            [st, {"Location" => "2?o=2"}, nil]
          end
        end
      end

      statuses.each do |st|
        {
          "/#{st}/host" => "http://example.com/#{st}/host/",
          "/#{st}/path" => "http://example.com/#{st}/path/",
        }.each do |input, prefix|
          res = c.post(input)
          assert_equal st, res.status_code
          assert_equal prefix + "2?o=2", res.location.url.to_s

          res = c.call(res.location)
          assert_equal st, res.status_code
          assert_equal prefix + "1?o=2", res.location.url.to_s

          res = c.call(res.location)
          assert_equal st, res.status_code
          assert_equal prefix + "0?o=2", res.location.url.to_s

          res = c.call(res.location)
          assert_equal 200, res.status_code
        end
      end
    end

    def test_integration_follow_post_redirect
      statuses = [307, 308]

      c = Client.new "http://example.com?o=1"
      c.request_options.redirection_limit = 0
      c.connection = Test.new do |t|
        statuses.each do |st|
          t.post "/#{st}/host/2" do |req|
            [st, {"Location" => "http://example.com/#{st}/host/1"}, nil]
          end

          t.post "/#{st}/host/1" do |req|
            [st, {"Location" => "http://example.com/#{st}/host/0"}, nil]
          end

          t.post "/#{st}/host/0" do |req|
            [200, {}, "ok"]
          end

          t.post "/#{st}/host" do |req|
            [st, {"Location" => "http://example.com/#{st}/host/2?o=2"}, nil]
          end

          t.post "/#{st}/path/2" do |req|
            [st, {"Location" => "/#{st}/path/1"}, nil]
          end

          t.post "/#{st}/path/1" do |req|
            [st, {"Location" => "/#{st}/path/0"}, nil]
          end

          t.post "/#{st}/path/0" do |req|
            [200, {}, "ok"]
          end

          t.post "/#{st}/path" do |req|
            [st, {"Location" => "2?o=2"}, nil]
          end
        end
      end

      statuses.each do |st|
        {
          "/#{st}/host" => "http://example.com/#{st}/host/",
          "/#{st}/path" => "http://example.com/#{st}/path/",
        }.each do |input, prefix|
          res = c.post(input)
          assert_equal st, res.status_code
          assert_equal prefix + "2?o=2", res.location.url.to_s

          res = c.call(res.location)
          assert_equal st, res.status_code
          assert_equal prefix + "1?o=2", res.location.url.to_s

          res = c.call(res.location)
          assert_equal st, res.status_code
          assert_equal prefix + "0?o=2", res.location.url.to_s

          res = c.call(res.location)
          assert_equal 200, res.status_code
        end
      end
    end

    def test_integration_automatic_redirection
      c = Client.new "https://example.com"
      c.connection = Test.new do |t|
        1.upto(5) do |i|
          t.get "/#{i}" do |req|
            [301, {"Location" => "/#{i - 1}"}, i.to_s]
          end
        end

        t.get "/0" do |req|
          [200, {}, "ok"]
        end
      end

      res = c.get("/5") { |r| r.options.redirection_limit = 10 }
      assert_equal "ok", res.body
      assert_equal [
        "https://example.com/5",
        "https://example.com/4",
        "https://example.com/3",
        "https://example.com/2",
        "https://example.com/1",
      ], res.via.map { |r| r.url.to_s }
      assert_equal "https://example.com/0", res.request.url.to_s

      res = c.get("/5") { |r| r.options.redirection_limit = 3 }
      assert_equal "2", res.body
      assert_equal [
        "https://example.com/5",
        "https://example.com/4",
        "https://example.com/3",
        ], res.via.map { |r| r.url.to_s }
        assert_equal "https://example.com/2", res.request.url.to_s
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
      c.request_options.bind = "bind:123"
      c.ssl_options.openssl_client_cert = "abc"

      req = c.request :get, "b"
      assert_equal "bind", req.options.bind.host
      assert_equal 123, req.options.bind.port
      assert_equal "abc", req.ssl_options.openssl_client_cert
      req.ssl_options.openssl_client_cert = "def"
      req.options.bind = "updated"

      assert_equal "*", req.header["Accept"]
      assert_equal "def", req.ssl_options.openssl_client_cert
      assert_equal "updated", req.options.bind.host
      assert_nil req.options.bind.port

      url = req.url
      assert_equal "https://example.com/a/b?a=1", url.to_s

      assert_equal "abc", c.ssl_options.openssl_client_cert
      assert_equal "bind", c.request_options.bind.host
      assert_equal 123, c.request_options.bind.port
    end

    def test_sets_before_callbacks
      c = Client.new nil
      c.before_call(:first) { |r| 1 }
      c.before_call { |r| 2 }
      c.before_call NamedCallback.new(:third, lambda { |r| 3 })

      callbacks = c.before_callbacks
      assert_equal 3, callbacks.size
      assert_equal :first, callbacks[0]
      assert callbacks[1].start_with?("#<Proc:")
      assert_equal :third, callbacks[2]
    end

    def test_sets_after_callbacks
      c = Client.new nil
      c.after_call(:first) { |r| 1 }
      c.after_call { |r| 2 }
      c.after_call NamedCallback.new(:third, lambda { |r| 3 })

      callbacks = c.after_callbacks
      assert_equal 3, callbacks.size
      assert_equal :first, callbacks[0]
      assert callbacks[1].start_with?("#<Proc:")
      assert_equal :third, callbacks[2]
    end

    SUCCESSFUL_RESPONSES = [200, 201, 202, 204, 205, 206]
    REDIRECTION_RESPONSES = [301, 302, 303, 307, 308]
    CLIENT_ERROR_RESPONSES = [400, 404, 405, 406, 409, 410, 422]
    SERVER_ERROR_RESPONSES = [500, 502, 503, 504]
    ALL_RESPONSES = SUCCESSFUL_RESPONSES + REDIRECTION_RESPONSES + CLIENT_ERROR_RESPONSES + SERVER_ERROR_RESPONSES + [100, 304]

    def test_knows_successful_responses
      bad = SUCCESSFUL_RESPONSES.reject do |st|
        res = Response.new(nil, st)
        res.success? && res.status_type == :success
      end
      assert_empty bad

      bad = (ALL_RESPONSES - SUCCESSFUL_RESPONSES).reject do |st|
        res = Response.new(nil, st)

        !Response.new(nil, st).success?
      end
      assert_empty bad
    end

    def test_knows_redirection_responses
      bad = REDIRECTION_RESPONSES.reject do |st|
        res = Response.new(nil, st)
        res.redirection? && res.status_type == :redirection
      end
      assert_empty bad

      bad = (ALL_RESPONSES - REDIRECTION_RESPONSES).reject do |st|
        res = Response.new(nil, st)
        !res.redirection? && res.status_type != :redirection
      end
      assert_empty bad
    end

    def test_knows_client_error_responses
      bad = CLIENT_ERROR_RESPONSES.reject do |st|
        res = Response.new(nil, st)
        res.client_error? && res.status_type == :client_error
      end
      assert_empty bad

      bad = (ALL_RESPONSES - CLIENT_ERROR_RESPONSES).reject do |st|
        res = Response.new(nil, st)
        !res.client_error? && res.status_type != :client_error
      end
      assert_empty bad
    end

    def test_knows_server_error_responses
      bad = SERVER_ERROR_RESPONSES.reject do |st|
        res = Response.new(nil, st)
        res.server_error? && res.status_type == :server_error
      end
      assert_empty bad

      bad = (ALL_RESPONSES - SERVER_ERROR_RESPONSES).reject do |st|
        res = Response.new(nil, st)
        !res.server_error? && res.status_type != :server_error
      end
      assert_empty bad
    end
  end
end
