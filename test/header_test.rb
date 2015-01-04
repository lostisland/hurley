require File.expand_path("../helper", __FILE__)

module Hurley
  class HeaderTest < TestCase
    def test_integration
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

    def test_empty_initial
      h = Header.new
      assert !h.key?(:content_type)
      assert_equal 0, h.size
      assert_equal [], h.keys
    end

    def test_initial
      h = Header.new :content_type => "text/plain"
      assert_equal 1, h.size
      assert_equal %w(Content-Type), h.keys
      [
        "Content-Type",
        "content-type",
        :content_type,
      ].each do |key|
        assert h.key?(key)
        assert_equal "text/plain", h[key]
      end
    end

    def test_set_and_get_key_with_shortcuts
      ["Content-Type", "content-type", :content_type, "CONTENT-TYPE"].each do |key|
        h = Header.new
        assert_nil h[key]

        h[key] = "text/plain"
        assert_equal %w(Content-Type), h.keys
        assert_equal "text/plain", h[key]
      end
    end

    def test_set_and_get_custom_key
      ["X-Hurley", "x-hurley", :x_hurley, "X-HURLEY"].each do |key|
        h = Header.new
        assert_nil h[key]

        h[key] = "text/plain"
        assert_equal %w(X-Hurley), h.keys
        assert_equal "text/plain", h[key]
      end
    end

    def test_delete_key
      h = Header.new :content_type => "text/plain"
      assert_equal %w(Content-Type), h.keys
      assert_equal "text/plain", h[:content_type]

      h.delete :content_type
      assert_equal [], h.keys
    end

    def test_iterate_keys
      h = Header.new :content_type => "text/plain", :content_length => 2
      assert_equal %w(Content-Type Content-Length), h.keys
      assert_equal "text/plain", h[:content_type]
      assert_equal "2", h[:content_length]

      pieces = []
      h.each do |key, value|
        pieces << "#{key}=#{value}"
      end

      assert_equal "Content-Type=text/plain\nContent-Length=2",
        pieces.join("\n")
    end

    def test_dup
      h1 = Header.new :content_type => "text/plain"
      h2 = h1
      h3 = h1.dup

      h2[:content_type] = "text/plain; charset=utf-8"
      h3[:content_type] = "image/gif"

      assert_equal "text/plain; charset=utf-8", h1[:content_type]
      assert_equal "text/plain; charset=utf-8", h2[:content_type]
      assert_equal "image/gif", h3[:content_type]
    end
  end
end
