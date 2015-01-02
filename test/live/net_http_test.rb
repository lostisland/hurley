require File.expand_path("../helper", __FILE__)

module Hurley
  module Live
    class NetHttpTest < TestCase
      Hurley::Test::Integration.apply(self)

      def connection
        Hurley.default_connection
      end
    end
  end
end
