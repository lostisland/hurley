module Hurley
  class Test
    module Integration
      def self.live_endpoint
        @live_endpoint ||= ENV["HURLEY_LIVE"]
      end

      def self.live_endpoint=(e)
        @live_endpoint = e
      end

      def self.apply(base)
        base.send(:include, Common)
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
    end
  end
end
