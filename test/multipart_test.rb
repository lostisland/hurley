require File.expand_path("../helper", __FILE__)

module Hurley
  class MultipartTest < TestCase
    def test_build_form_with_flat_query
      ctype, body = Query::Flat.new(:a => [1,2,3]).to_form
      assert_equal "application/x-www-form-urlencoded", ctype
      assert_equal "a=1&a=2&a=3", body.read
    end

    def test_build_form_with_nested_query
      ctype, body = Query::Nested.new(:a => {:b => 2}).to_form
      assert_equal "application/x-www-form-urlencoded", ctype
      assert_equal "a%5Bb%5D=2", body.read
    end

    def test_build_multipart_with_set_boundary
      options = RequestOptions.new
      options.boundary = :wat

      ctype, _ = Query::Nested.new(:file => UploadIO.new(__FILE__, "text/plain")).to_form(options)
      assert_equal "multipart/form-data; boundary=wat", ctype
    end

    def test_build_multipart_with_flat_query
      ctype, body = Query::Flat.new(
        :a => 1,
        :array => [1, 2],
        :file => UploadIO.new(__FILE__, "text/plain"),
      ).to_form

      src = IO.read(__FILE__)

      boundary = nil
      if ctype =~ %r{\Amultipart/form-data; boundary=(Hurley\-.*)}
        boundary = $1
      else
        fail "bad ctype: #{ctype.inspect}"
      end

      assert_match %r{\Amultipart/form-data; boundary=Hurley\-}, ctype
      expected = %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="a"\r\n) +
        %(\r\n1\r\n) +

        %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="array"\r\n) +
        %(\r\n1\r\n) +

        %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="array"\r\n) +
        %(\r\n2\r\n) +

        %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="file"; filename="multipart_test.rb"\r\n) +
        %(Content-Length: #{src.size}\r\n) +
        %(Content-Type: text/plain\r\n) +
        %(Content-Transfer-Encoding: binary\r\n) +
        %(\r\n#{src}\r\n) +

        %(--#{boundary}--\r\n\r\n)

      assert_equal expected, body.read.to_s
    end

    def test_build_multipart_with_nested_query
      ctype, body = Query::Nested.new(:a => {
        :num => 1,
        :arr => [1, 2],
        :file => UploadIO.new(__FILE__, "text/plain"),
      }).to_form

      src = IO.read(__FILE__)

      boundary = nil
      if ctype =~ %r{\Amultipart/form-data; boundary=(Hurley\-.*)}
        boundary = $1
      else
        fail "bad ctype: #{ctype.inspect}"
      end

      expected = %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="a[num]"\r\n) +
        %(\r\n1\r\n) +

        %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="a[arr][]"\r\n) +
        %(\r\n1\r\n) +

        %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="a[arr][]"\r\n) +
        %(\r\n2\r\n) +

        %(--#{boundary}\r\n) +
        %(Content-Disposition: form-data; name="a[file]"; filename="multipart_test.rb"\r\n) +
        %(Content-Length: #{src.size}\r\n) +
        %(Content-Type: text/plain\r\n) +
        %(Content-Transfer-Encoding: binary\r\n) +
        %(\r\n#{src}\r\n) +

        %(--#{boundary}--\r\n\r\n)

      assert_equal expected, body.read.to_s
    end
  end

  class ParamPartTest < TestCase
    def test_build_without_content_type
      part = Multipart::Part.new("boundary", "foo", "bar", {})
      expected = %(--boundary\r\n) +
        %(Content-Disposition: form-data; name="foo"\r\n) +
        %(\r\nbar\r\n)
      assert_equal expected.size, part.length
      assert_equal expected, part.to_io.read
    end

    def test_build_with_content_type
      part = Multipart::Part.new("boundary", "foo", "bar",
        :content_type => "text/plain")
      expected = %(--boundary\r\n) +
        %(Content-Disposition: form-data; name="foo"\r\n) +
        %(Content-Type: text/plain\r\n) +
        %(\r\nbar\r\n)
      assert_equal expected.size, part.length
      assert_equal expected, part.to_io.read
    end
  end

  class FilePartTest < TestCase
    def test_build_without_options
      src = IO.read(__FILE__)
      io = UploadIO.new(__FILE__, "text/plain")

      part = Multipart::Part.new("boundary", "foo", io, {})

      expected = %(--boundary\r\n) +
        %(Content-Disposition: form-data; name="foo"; filename="multipart_test.rb"\r\n) +
        %(Content-Length: #{src.size}\r\n) +
        %(Content-Type: text/plain\r\n) +
        %(Content-Transfer-Encoding: binary\r\n) +
        %(\r\n#{src}\r\n)

      assert_equal expected.size, part.length
      assert_equal expected, part.to_io.read
    end

    def test_build_with_content_type
      src = IO.read(__FILE__)
      io = UploadIO.new(__FILE__, "text/plain")

      part = Multipart::Part.new("boundary", "foo", io,
        :content_type => "text/ruby")

      expected = %(--boundary\r\n) +
        %(Content-Disposition: form-data; name="foo"; filename="multipart_test.rb"\r\n) +
        %(Content-Length: #{src.size}\r\n) +
        %(Content-Type: text/ruby\r\n) +
        %(Content-Transfer-Encoding: binary\r\n) +
        %(\r\n#{src}\r\n)

      assert_equal expected.size, part.length
      assert_equal expected, part.to_io.read
    end

    def test_build_with_content_disposition
      src = IO.read(__FILE__)
      io = UploadIO.new(__FILE__, "text/plain")

      part = Multipart::Part.new("boundary", "foo", io,
        :content_disposition => "attachment")

      expected = %(--boundary\r\n) +
        %(Content-Disposition: attachment; name="foo"; filename="multipart_test.rb"\r\n) +
        %(Content-Length: #{src.size}\r\n) +
        %(Content-Type: text/plain\r\n) +
        %(Content-Transfer-Encoding: binary\r\n) +
        %(\r\n#{src}\r\n)

      assert_equal expected.size, part.length
      assert_equal expected, part.to_io.read
    end

    def test_build_with_content_transfer_encoding
      src = IO.read(__FILE__)
      io = UploadIO.new(__FILE__, "text/plain")

      part = Multipart::Part.new("boundary", "foo", io,
        :content_transfer_encoding => "rofl")

      expected = %(--boundary\r\n) +
        %(Content-Disposition: form-data; name="foo"; filename="multipart_test.rb"\r\n) +
        %(Content-Length: #{src.size}\r\n) +
        %(Content-Type: text/plain\r\n) +
        %(Content-Transfer-Encoding: rofl\r\n) +
        %(\r\n#{src}\r\n)

      assert_equal expected.size, part.length
      assert_equal expected, part.to_io.read
    end

    def test_build_with_content_id
      src = IO.read(__FILE__)
      io = UploadIO.new(__FILE__, "text/plain")

      part = Multipart::Part.new("boundary", "foo", io,
        :content_id => "abc123")

      expected = %(--boundary\r\n) +
        %(Content-Disposition: form-data; name="foo"; filename="multipart_test.rb"\r\n) +
        %(Content-Length: #{src.size}\r\n) +
        %(Content-ID: abc123\r\n) +
        %(Content-Type: text/plain\r\n) +
        %(Content-Transfer-Encoding: binary\r\n) +
        %(\r\n#{src}\r\n)

      assert_equal expected.size, part.length
      assert_equal expected, part.to_io.read
    end
  end

  class CompositeReadIOTest < TestCase
    def test_read_all
      io = CompositeReadIO.new StringIO.new("one"), StringIO.new("two")
      assert_equal "onetwo", io.read
    end

    def test_read_chunks
      io = CompositeReadIO.new StringIO.new("one"), StringIO.new("two")
      assert_equal "on", io.read(2)
      assert_equal "et", io.read(2)
      assert_equal "wo", io.read(2)
      assert_nil io.read(2)

      io.rewind

      assert_equal "on", io.read(2)
      assert_equal "et", io.read(2)
      assert_equal "wo", io.read(2)
      assert_nil io.read(2)

      io.rewind

      assert_equal "one", io.read(3)
      assert_equal "two", io.read(3)
      assert_nil io.read(3)
    end
  end

  class UploadIOTest < TestCase
    def test_with_filename_and_no_custom_filename
      io = UploadIO.new(__FILE__, "text/plain")
      assert_equal "text/plain", io.content_type
      assert_equal "multipart_test.rb", io.original_filename
      assert_equal __FILE__, io.local_path
      assert_empty io.opts
      assert_equal IO.read(__FILE__), io.read
    end

    def test_with_filename_and_custom_filename
      io = UploadIO.new(__FILE__, "text/plain", "wat.rb")
      assert_equal "text/plain", io.content_type
      assert_equal "wat.rb", io.original_filename
      assert_equal __FILE__, io.local_path
      assert_empty io.opts
      assert_equal IO.read(__FILE__), io.read
    end

    def test_with_file_io_and_no_custom_filename
      io = UploadIO.new(File.new(__FILE__), "text/plain")
      assert_equal "text/plain", io.content_type
      assert_equal "multipart_test.rb", io.original_filename
      assert_equal __FILE__, io.local_path
      assert_empty io.opts
      assert_equal IO.read(__FILE__), io.read
    end

    def test_with_file_io_and_custom_filename
      io = UploadIO.new(File.new(__FILE__), "text/plain", "wat.rb")
      assert_equal "text/plain", io.content_type
      assert_equal "wat.rb", io.original_filename
      assert_equal __FILE__, io.local_path
      assert_empty io.opts
      assert_equal IO.read(__FILE__), io.read
    end

    def test_with_io_and_no_custom_filename
      stringio = StringIO.new(IO.read(__FILE__))
      io = UploadIO.new(stringio, "text/plain")
      assert_equal "text/plain", io.content_type
      assert_equal "local.path", io.original_filename
      assert_equal "local.path", io.local_path
      assert_empty io.opts
      assert_equal IO.read(__FILE__), io.read
    end

    def test_with_io_and_custom_filename
      stringio = StringIO.new(IO.read(__FILE__))
      io = UploadIO.new(stringio, "text/plain", "wat.rb")
      assert_equal "text/plain", io.content_type
      assert_equal "wat.rb", io.original_filename
      assert_equal "local.path", io.local_path
      assert_empty io.opts
      assert_equal IO.read(__FILE__), io.read
    end
  end
end
