require File.expand_path("../../helper", __FILE__)
Hurley.require_lib "connection"

module Hurley
  module Live
    class NetHttpTest < TestCase
      features = []

      if Hurley::Connection::ATTEMPT_GZIP && RUBY_VERSION >= "1.9"
        features << :Compression
      end

      Hurley::Test::Integration.apply(self, *features)

      def connection
        Hurley.default_connection
      end
    end
  end
end
