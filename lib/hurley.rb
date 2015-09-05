require "forwardable"
require "thread"

module Hurley
  VERSION = "0.2".freeze
  USER_AGENT = "Hurley v#{VERSION}".freeze
  LIB_PATH = __FILE__[0...-3]
  MUTEX = Mutex.new

  def self.require_lib(*libs)
    libs.each do |lib|
      require File.join(LIB_PATH, lib)
    end
  end

  def self.default_client
    mutex do
      @default_client ||= Client.new
    end
  end

  class << self
    extend Forwardable
    def_delegators(:default_client,
      :head,
      :get,
      :patch,
      :put,
      :post,
      :delete,
      :options,
    )
  end

  def self.default_connection
    mutex do
      @default_connection ||= begin
        Hurley.require_lib "connection"
        Connection.new
      end
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
      elsif ex.respond_to?(:status_code)
        super("the server responded with status #{ex.status_code}")
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
      %(#<#{self.class}: #{@wrapped_exception.class}>)
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
    "multipart",
    "options",
    "header",
    "url",
    "query",
    "client",
  )

  if defined?(Addressable::URI)
    require_lib "addressable"
  end
end
