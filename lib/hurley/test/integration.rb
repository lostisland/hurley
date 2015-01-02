module Hurley
  class Test
    module Integration
      def self.live_endpoint
        @live_endpoint ||= ENV["HURLEY_LIVE"]
      end

      def self.live_endpoint=(e)
        @live_endpoint = e
      end

      def self.ssl?
        if @ssl.nil?
          @ssl = !ENV["HURLEY_SSL"].to_s.empty?
        end
        @ssl
      end

      def self.ssl=(bool)
        @ssl = bool
      end

      self.ssl = nil

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
          end
        end
      end

      module SSL
        def test_GET_ssl_fails_with_bad_cert
          err = assert_raises Hurley::SSLError do
            client.get("/ssl")
          end
          assert_includes err.message, "certificate"
        end
      end
    end
  end
end
