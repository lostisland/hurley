require File.expand_path("../../helper", __FILE__)

module Hurley
  module Live
    class NetHttpTest < TestCase
      def client
        @client ||= Client.new(ENV["HURLEY_LIVE"]) do |cli|
          cli.header["X-Hurley-Connection"] = connection.class.name
          cli.connection = connection
        end
      end

      def connection
        Hurley.default_connection
      end

      def test_GET_retrieves_the_response_body
        assert_equal "get", client.get("/echo").body
      end

      def test_empty_body_response_represented_as_nil
        res = client.get("204")
        assert_equal 204, res.status_code
        assert_nil res.body
      end
    end
  end
end
