require File.expand_path("../helper", __FILE__)

module Hurley
  class QueryTest < TestCase
    def test_encode_and_parse_string_value
      q = Query::Nested.new
      q["a"] = 1

      assert !q.key?("a+b")
      assert_nil q["a+b"]
      q["a+b"] = "1+2"
      assert_equal "1+2", q["a+b"]
      assert q.key?("a+b")

      assert_equal "a=1&a%2Bb=1%2B2", q.to_query_string

      q2 = Query.parse(q.to_query_string)
      assert_equal %w(a a+b), q2.keys
      assert_equal "1", q2["a"]
      assert_equal "1+2", q2["a+b"]
    end

    def test_encode_and_parse_nil_value
      q = Query::Nested.new
      q["a"] = 1
      assert !q.key?("a+b")
      assert_nil q["a+b"]
      q["a+b"] = nil
      assert_nil q["a+b"]
      assert q.key?("a+b")

      assert_equal "a=1&a%2Bb", q.to_query_string

      q2 = Query.parse(q.to_query_string)
      assert_equal %w(a a+b), q2.keys
      assert_equal "1", q2["a"]
      assert_nil q2["a+b"]
    end

    def test_delete_value
      q = Query::Nested.new
      q["a+b"] = "1+2"
      assert_equal "a%2Bb=1%2B2", q.to_query_string
      q.delete "a+b"
      assert_equal "", q.to_query_string
    end

    def test_encode_and_parse_array_value_in_nested_query
      q = Query::Nested.new
      q["a"] = 1
      q["a+b"] = %w(1+1 2+2 3+3)
      assert_query "a=1&a%2Bb[]=1%2B1&a%2Bb[]=2%2B2&a%2Bb[]=3%2B3", q.to_query_string

      q2 = Query::Nested.parse(q.to_query_string)
      assert_equal %w(a a+b), q2.keys
      assert_equal "1", q2["a"]
      assert_equal %w(1+1 2+2 3+3), q2["a+b"]
    end

    def test_encode_and_parse_array_value_in_flat_query
      q = Query::Flat.new
      q["a"] = 1
      q["a+b"] = %w(1+1 2+2 3+3)
      assert_equal "a=1&a%2Bb=1%2B1&a%2Bb=2%2B2&a%2Bb=3%2B3", q.to_query_string

      q2 = Query::Flat.parse(q.to_query_string)
      assert_equal %w(a a+b), q2.keys
      assert_equal "1", q2["a"]
      assert_equal %w(1+1 2+2 3+3), q2["a+b"]
    end

    def test_encode_and_parse_simple_hash_value_in_nested_query
      q = Query::Nested.new
      q["a"] = 1
      q["a+b"] = {"1+1" => "a+a", "2+2" => "b+b"}
      assert_query "a=1&a%2Bb[1%2B1]=a%2Ba&a%2Bb[2%2B2]=b%2Bb", q.to_query_string

      q2 = Query::Nested.parse(q.to_query_string)
      assert_equal %w(a a+b), q2.keys
      assert_equal "1", q2["a"]
      assert_equal %w(1+1 2+2), q2["a+b"].keys
      assert_equal "a+a", q2["a+b"]["1+1"]
      assert_equal "b+b", q2["a+b"]["2+2"]
    end

    def test_encode_and_parse_deeply_nested_hash
      q = Query::Nested.new
      q["a"] = 1
      q["a+1"] = {
        "b+2" => {
          "c+3" => "d+4",
          "c+wat" => "c",
        },
        "b+wat" => "b"
      }

      assert_query "a=1&a%2B1[b%2B2][c%2B3]=d%2B4&a%2B1[b%2B2][c%2Bwat]=c&a%2B1[b%2Bwat]=b", q.to_query_string
      q2 = Query::Nested.parse(q.to_query_string)
      assert_equal %w(a a+1), q2.keys
      assert_equal "1", q2["a"]

      assert_equal %w(b+2 b+wat), q2["a+1"].keys
      assert_equal %w(c+3 c+wat), q2["a+1"]["b+2"].keys
      assert_equal "b", q2["a+1"]["b+wat"]
      assert_equal "c", q2["a+1"]["b+2"]["c+wat"]
      assert_equal "d+4", q2["a+1"]["b+2"]["c+3"]
    end

    def test_encode_and_parse_deeply_nested_array
      q = Query::Nested.new
      q["a"] = 1
      q["a+1"] = {
        "b+2" => {
          "c+3" => %w(d+4 d),
          "c+wat" => "c",
        },
        "b+wat" => "b"
      }

      assert_query "a=1&a%2B1[b%2B2][c%2B3][]=d%2B4&a%2B1[b%2B2][c%2B3][]=d&a%2B1[b%2B2][c%2Bwat]=c&a%2B1[b%2Bwat]=b", q.to_query_string
      q2 = Query::Nested.parse(q.to_query_string)
      assert_equal %w(a a+1), q2.keys
      assert_equal "1", q2["a"]

      assert_equal %w(b+2 b+wat), q2["a+1"].keys
      assert_equal %w(c+3 c+wat), q2["a+1"]["b+2"].keys
      assert_equal "b", q2["a+1"]["b+wat"]
      assert_equal "c", q2["a+1"]["b+2"]["c+wat"]
      assert_equal %w(d+4 d), q2["a+1"]["b+2"]["c+3"]
    end

    def test_encode_and_parse_deeply_nested_key
      q = Query::Nested.new
      q["a"] = 1
      q["a+1"] = [ # 1
        { # 2
          "b+2" => { # 3
            "c+3" => [ # 4
              {"d+4" => %w(e 5)}
            ]
          }
        }
      ]

      assert_query "a=1&a%2B1[][b%2B2][c%2B3][][d%2B4][]=e&a%2B1[][b%2B2][c%2B3][][d%2B4][]=5", q.to_query_string
      q2 = Query::Nested.parse(q.to_query_string)
      assert_equal %w(a a+1), q2.keys
      assert_equal "1", q2["a"]

      arr1 = q2["a+1"]
      assert_equal 2, arr1.size
      hash2 = arr1[0]
      assert_equal %w(b+2), hash2.keys
      hash3 = hash2["b+2"]
      assert_equal %w(c+3), hash3.keys
      arr4 = hash3["c+3"]
      assert_equal 1, arr4.size
      hash5 = arr4[0]
      assert_equal %w(e), hash5["d+4"]

      hash2 = arr1[1]
      assert_equal %w(b+2), hash2.keys
      hash3 = hash2["b+2"]
      assert_equal %w(c+3), hash3.keys
      arr4 = hash3["c+3"]
      assert_equal 1, arr4.size
      hash5 = arr4[0]
      assert_equal %w(5), hash5["d+4"]
    end

    def test_encode_hash_value_in_flat_query
      q = Query::Flat.new
      q["a"] = {1 => "a", 2 => "b"}
      assert_raises NotImplementedError do
        q.to_query_string
      end
    end

    def test_parse_hash_value_in_flat_query
      q = Query::Flat.parse("a=1&a%2Ba[1%2B1]=a%2Ba&a%2Ba[2%2B2]=b%2Bb")
      assert_equal %w(a a+a[1+1] a+a[2+2]), q.keys
    end

    def assert_query(expected, actual)
      expected.gsub! /\[|\]/, "[" => "%5B", "]" => "%5D"
      assert_equal expected, actual
    end

    def test_parse_double_equal_sign_in_nested_query
      q = Query::Nested.parse("a[]=1&b[]=2&&c[]=3")
      assert_equal %w(a b c), q.keys
    end

    def test_parse_double_equal_sign_in_flat_query
      q = Query::Flat.parse("a[]=1&b[]=2&&c[]=3")
      assert_equal %w(a[] b[] c[]), q.keys
    end
  end
end
