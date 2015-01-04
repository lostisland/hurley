# Taken from multipart-post gem: https://github.com/nicksieger/multipart-post
# Removes coupling with net/http

module Hurley
  # Convenience methods for dealing with files and IO that are to be uploaded.
  class UploadIO
    # Create an upload IO suitable for including in the body hash of a
    # Hurley::Request.
    #
    # Can take two forms. The first accepts a filename and content type, and
    # opens the file for reading (to be closed by finalizer).
    #
    # The second accepts an already-open IO, but also requires a third argument,
    # the filename from which it was opened (particularly useful/recommended if
    # uploading directly from a form in a framework, which often save the file to
    # an arbitrarily named RackMultipart file in /tmp).
    #
    # Usage:
    #
    #     UploadIO.new("file.txt", "text/plain")
    #     UploadIO.new(file_io, "text/plain", "file.txt")
    #
    attr_reader :content_type, :original_filename, :local_path, :io, :opts

    def initialize(filename_or_io, content_type, filename = nil, opts = {})
      io = filename_or_io
      local_path = nil
      if io.respond_to?(:read)
        # in Ruby 1.9.2, StringIOs no longer respond to path
        # (since they respond to :length, so we don't need their local path, see parts.rb:41)
        local_path = filename_or_io.respond_to?(:path) ? filename_or_io.path : DEFAULT_LOCAL_PATH
      else
        io = File.open(filename_or_io)
        local_path = filename_or_io
      end

      filename ||= local_path

      @content_type = content_type
      @original_filename = File.basename(filename)
      @local_path = local_path
      @io = io
      @opts = opts
    end

    def method_missing(*args)
      @io.send(*args)
    end

    def respond_to?(meth, include_all = false)
      @io.respond_to?(meth, include_all) || super(meth, include_all)
    end

    DEFAULT_LOCAL_PATH = "local.path".freeze
  end

  # Internal helper classes for generating multipart bodies.
  module Multipart
    module Part #:nodoc:
      def self.new(boundary, name, value, header = nil)
        header ||= {}
        if file?(value)
          FilePart.new(boundary, name, value, header)
        else
          ParamPart.new(boundary, name, value, header)
        end
      end

      def self.file?(value)
        value.respond_to?(:content_type) && value.respond_to?(:original_filename)
      end

      def to_io
        @io
      end
    end

    class ParamPart
      include Part

      def initialize(boundary, name, value, header)
        @part = build_part(boundary, name, value, header)
        @io = StringIO.new(@part)
      end

      def length
        @part.bytesize
      end

      private

      def build_part(boundary, name, value, header)
        ctype = if type = header[:content_type]
          CTYPE_FORMAT % type
        end

        PART_FORMAT % [
          boundary,
          name.to_s,
          ctype,
          value.to_s,
        ]
      end

      CTYPE_FORMAT = "Content-Type: %s\r\n"
      PART_FORMAT = <<-END
--%s\r
Content-Disposition: form-data; name="%s"\r
%s\r
%s\r
END
    end

    # Represents a part to be filled from file IO.
    class FilePart
      include Part

      attr_reader :length

      def initialize(boundary, name, io, header)
        file_length = io.respond_to?(:length) ?  io.length : File.size(io.local_path)

        @head = build_head(boundary, name, io.original_filename, io.content_type, file_length,
                           io.respond_to?(:opts) ? io.opts.merge(header) : header)

        @length = @head.bytesize + file_length + FOOT.length
        @io = CompositeReadIO.new(@length, StringIO.new(@head), io, StringIO.new(FOOT))
      end

      private

      def build_head(boundary, name, filename, type, content_len, header)
        content_id = if cid = header[:content_id]
          CID_FORMAT % cid
        end


        HEAD_FORMAT % [
          boundary,
          header[:content_disposition] || DEFAULT_DISPOSITION,
          name.to_s,
          filename.to_s,
          content_len.to_i,
          content_id,
          header[:content_type] || type,
          header[:content_transfer_encoding] || DEFAULT_TR_ENCODING,
        ]
      end

      DEFAULT_TR_ENCODING = "binary".freeze
      DEFAULT_DISPOSITION = "form-data".freeze
      FOOT = "\r\n".freeze
      CID_FORMAT = "Content-ID: %s\r\n"
      HEAD_FORMAT = <<-END
--%s\r
Content-Disposition: %s; name="%s"; filename="%s"\r
Content-Length: %d\r
%sContent-Type: %s\r
Content-Transfer-Encoding: %s\r
\r
END
    end

    # Represents the epilogue or closing boundary.
    class EpiloguePart
      include Part

      attr_reader :length

      def initialize(boundary)
        @part = "--#{boundary}--\r\n\r\n"
        @io = StringIO.new(@part)
        @length = @part.bytesize
      end
    end
  end

  # Concatenate together multiple IO objects into a single, composite IO object
  # for purposes of reading as a single stream.
  #
  # Usage:
  #
  #     crio = CompositeReadIO.new(StringIO.new('one'), StringIO.new('two'), StringIO.new('three'))
  #     puts crio.read # => "onetwothree"
  class CompositeReadIO
    attr_reader :length

    def initialize(length = nil, *ios)
      @ios = ios.flatten

      if length.respond_to?(:read)
        @ios.unshift(length)
      else
        @length = length || -1
      end

      @index = 0
    end

    def read(length = nil, outbuf = nil)
      got_result = false
      outbuf = outbuf ? outbuf.replace("") : ""

      while io = current_io
        if result = io.read(length)
          got_result ||= !result.nil?
          result.force_encoding(BINARY) if result.respond_to?(:force_encoding)
          outbuf << result
          length -= result.length if length
          break if length == 0
        end
        advance_io
      end

      (!got_result && length) ? nil : outbuf
    end

    def rewind
      @ios.each { |io| io.rewind }
      @index = 0
    end

    private

    def current_io
      @ios[@index]
    end

    def advance_io
      @index += 1
    end

    BINARY = "BINARY".freeze
  end
end
