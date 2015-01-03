require "minitest/autorun"
require File.expand_path("../../lib/hurley", __FILE__)
Hurley.require_lib "test", "test/integration"

module Hurley
  class TestCase < MiniTest::Test
  end
end
