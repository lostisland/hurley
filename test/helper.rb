require "minitest/autorun"
require "rack"

if ENV["HURLEY_ADDRESSABLE"]
  require "addressable/uri"
end

require File.expand_path("../../lib/hurley", __FILE__)
Hurley.require_lib "test", "test/integration"

module Hurley
  class TestCase < MiniTest::Test
  end
end
