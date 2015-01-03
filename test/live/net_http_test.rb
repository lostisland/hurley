require File.expand_path("../../helper", __FILE__)

module Hurley
  module Live
    class NetHttpTest < TestCase
      features = []
      features << :Compression if RUBY_VERSION >= "1.9"

      Hurley::Test::Integration.apply(self, *features)

      def connection
        Hurley.default_connection
      end
    end
  end
end
