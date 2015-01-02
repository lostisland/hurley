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

        def test_empty_body_response_represented_as_nil
          res = client.get("204")
          assert_equal 204, res.status_code
          assert_nil res.body
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
      end

      module SSL
        def test_GET_ssl_fails_with_bad_cert
          client.ssl_options.ca_file = "tmp/hurley-different-ca-cert.crt"

          err = assert_raises Hurley::SSLError do
            client.get("/ssl")
          end

          assert_includes err.message, "certificate"
        end
      end
    end
  end
end
