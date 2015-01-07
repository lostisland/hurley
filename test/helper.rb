require "minitest/autorun"
require "rack"

if ENV["HURLEY_ADDRESSABLE"]
  require "addressable/uri"
end

require File.expand_path("../../lib/hurley", __FILE__)
Hurley.require_lib "test", "test/integration"

puts $LOAD_PATH

module Hurley
  base_class = defined?(MiniTest::Test) ? MiniTest::Test : MiniTest::Unit::TestCase
  TestCase = Class.new(base_class)
end
