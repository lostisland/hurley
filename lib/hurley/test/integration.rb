module Hurley
  class Test
    module Integration
      class << self
        attr_writer :live_endpoint
        attr_writer :ssl_file

        def live_endpoint
          @live_endpoint ||= ENV["HURLEY_LIVE"].to_s
        end

        def ssl_file
          @ssl_file ||= ENV["HURLEY_SSL_FILE"].to_s
        end

        def ssl?
          live_endpoint.start_with?(Hurley::HTTPS)
        end
      end

      def self.apply(base, *extra_features)
        features = [:Common, *extra_features]
        features << :SSL if Integration.ssl?
        features.each do |name|
          base.send(:include, const_get(name))
        end
      end

      module Common
        def test_GET_retrieves_the_response_body
          assert_equal "get", client.get("echo").body
        end

        def test_GET_send_url_encoded_params
          assert_equal %(get ?{"name"=>"zack"}), client.get("echo", :name => :zack).body
        end

        def test_GET_retrieves_the_response_headers
          response = client.get("echo")
          assert_match(/text\/plain/, response.header["Content-Type"])
          assert_match(/text\/plain/, response.header["content-type"])
          assert_match(/text\/plain/, response.header[:content_type])
        end

        def test_GET_sends_user_agent
          assert_equal Hurley::USER_AGENT, client.get("echo_header", :name => :user_agent).body
        end

        def test_GET_ssl
          expected = Integration.ssl?.to_s
          assert_equal expected, client.get("ssl").body
        end

        def test_POST_send_url_encoded_params
          res = client.post "echo" do |req|
            req.body = "name=zack"
            req.header[:content_type] = "application/x-www-form-urlencoded"
          end
          assert_equal %(post {"name"=>"zack"}), res.body
        end

        def test_POST_send_url_encoded_nested_params
          res = client.post "echo" do |req|
            req.body = "name[first]=zack"
            req.header[:content_type] = "application/x-www-form-urlencoded"
          end
          assert_equal %(post {"name"=>{"first"=>"zack"}}), res.body
        end

        def test_POST_retrieves_the_response_headers
          assert_match(/text\/plain/, client.post("echo").header[:content_type])
        end

        def test_POST_sends_files_as_multipart
          resp = client.post("file") do |req|
            ctype, body = Query::Flat.new(
              :uploaded_file => UploadIO.new(__FILE__, "text/x-ruby"),
            ).to_form
            req.header[:content_type] = ctype
            req.body = body
          end
          assert_equal "file integration.rb text/x-ruby #{File.size(__FILE__)}", resp.body
        end

        def test_PUT_sends_files
          resp = client.put("raw") do |req|
            req.header[:content_length] = File.size(__FILE__)
            req.body = File.open(__FILE__)
          end
          assert_equal "raw application/octet-stream #{File.size(__FILE__)} #{File.size(__FILE__)}", resp.body
        end

        def test_PUT_sends_io
          resp = client.put("raw") do |req|
            req.body = GenericIO.new("READ")
            req.header[:content_length] = 4
          end
          assert_equal "raw application/octet-stream 4 4", resp.body
        end

        def test_PUT_sends_io_with_chunked_encoding
          resp = client.put("raw") do |req|
            req.body = GenericIO.new("READ")
          end
          assert_equal "raw application/octet-stream -1 4", resp.body
        end

        def test_PUT_send_url_encoded_params
          res = client.put "echo" do |req|
            req.body = "name=zack"
            req.header[:content_type] = "application/x-www-form-urlencoded"
          end
          assert_equal %(put {"name"=>"zack"}), res.body
        end

        def test_PUT_send_url_encoded_nested_params
          res = client.put "echo" do |req|
            req.body = "name[first]=zack"
            req.header[:content_type] = "application/x-www-form-urlencoded"
          end
          assert_equal %(put {"name"=>{"first"=>"zack"}}), res.body
        end

        def test_PUT_retrieves_the_response_headers
          assert_match(/text\/plain/, client.put("echo").header[:content_type])
        end

        def test_PATCH_send_url_encoded_params
          res = client.patch "echo" do |req|
            req.header[:content_type] = "application/x-www-form-urlencoded"
            req.body = "name=zack"
          end
          assert_equal %(patch {"name"=>"zack"}), res.body
        end

        def test_OPTIONS
          assert_equal "options", client.options("echo").body
        end

        def test_HEAD_retrieves_no_response_body
          assert_nil client.head("echo").body
        end

        def test_HEAD_retrieves_the_response_headers
          assert_match(/text\/plain/, client.head("echo").header[:content_type])
        end

        def test_DELETE_retrieves_the_response_headers
          assert_match(/text\/plain/, client.delete("echo").header[:content_type])
        end

        def test_DELETE_retrieves_the_body
          assert_equal %(delete), client.delete("echo").body
        end

        def test_timeout
          client.request_options.timeout = 0.5
          assert_raises Hurley::Timeout do
            client.get "/slow"
          end
        end

        def test_connection_error
          assert_raises Hurley::ConnectionFailed do
            client.get "http://localhost:4"
          end
        end

        def test_empty_body_response_represented_as_nil
          res = client.get("204")
          assert_equal 204, res.status_code
          assert_nil res.body
        end

        def test_proxy
          return unless client.request_options.proxy = proxy_url

          res = client.get("/echo")
          assert_equal "get", res.body

          unless Integration.ssl?
            # proxy can't append "Via" header for HTTPS responses
            assert_match(/:#{proxy_url.port}$/, res.header[:Via])
          end
        end

        def test_proxy_auth_fail
          return unless client.request_options.proxy = proxy_url
          client.request_options.proxy.password = "WRONG"
          assert_equal 407, client.put("/echo").status_code
        rescue Hurley::ConnectionFailed
          # this exception is allowed too
        end

        def client
          @client ||= Client.new(Integration.live_endpoint) do |cli|
            cli.header["X-Hurley-Connection"] = connection.class.name
            cli.connection = connection

            if Integration.ssl?
              cli.ssl_options.ca_file = Integration.ssl_file
            end
          end
        end

        def proxy_url
          @proxy_url ||= if raw_url = ENV["HURLEY_PROXY"]
            Url.parse(raw_url)
          end
        end
      end

      module Compression
        def test_GET_handles_compression
          res = client.get("echo_header", :name => :accept_encoding)
          assert_match(/gzip;.+\bdeflate\b/, res.body)
        end
      end

      module SSL
        def test_GET_ssl_fails_with_bad_cert
          client.ssl_options.ca_file = "tmp/hurley-different-ca-cert.crt"

          err = assert_raises Hurley::SSLError do
            client.get("/ssl")
          end

          assert_includes err.message, "certificate"
        end

        def test_GET_ssl_skips_verification
          client.ssl_options.ca_file = "tmp/hurley-different-ca-cert.crt"
          client.ssl_options.skip_verification = true
          assert_equal "true", client.get("/ssl").body
        end
      end

      class GenericIO
        def initialize(str)
          @io = StringIO.new(str)
        end

        def read(*args)
          @io.read(*args)
        end
      end
    end
  end
end
