require "thread"

module Hurley
  VERSION = "0.1".freeze
  USER_AGENT = "Hurley v#{VERSION}".freeze
  LIB_PATH = __FILE__[0...-3]
  MUTEX = Mutex.new

  def self.require_lib(*libs)
    libs.each do |lib|
      require File.join(LIB_PATH, lib)
    end
  end

  def self.default_connection
    @default_connection ||= mutex do
      Hurley.require_lib "connection"
      Connection.new
    end
  end

  def self.mutex
    MUTEX.synchronize(&Proc.new)
  end

  class Error < StandardError; end

  class ClientError < Error
    attr_reader :response

    def initialize(ex, response = nil)
      @wrapped_exception = nil
      @response = response

      if ex.respond_to?(:backtrace)
        super(ex.message)
        @wrapped_exception = ex
      elsif ex.respond_to?(:each_key)
        super("the server responded with status #{ex[:status]}")
        @response = ex
      else
        super(ex.to_s)
      end
    end

    def backtrace
      if @wrapped_exception
        @wrapped_exception.backtrace
      else
        super
      end
    end

    def inspect
      %(#<#{self.class}>)
    end
  end

  class ConnectionFailed < ClientError;   end
  class ResourceNotFound < ClientError;   end
  class ParsingError     < ClientError;   end

  class Timeout < ClientError
    def initialize(ex = nil)
      super(ex || "timeout")
    end
  end

  class SSLError < ClientError
  end

  HTTPS = "https".freeze

  require_lib(
    "options",
    "header",
    "url",
    "query",
    "client",
  )
end
