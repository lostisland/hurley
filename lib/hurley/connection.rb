begin
  require "net/https"
rescue LoadError
  warn "Warning: no such file to load -- net/https. Make sure openssl is installed if you want ssl support"
  require "net/http"
end
require "zlib"

module Hurley
  class Connection
    def call(request)
      net_http_connection(request) do |http|
        begin
          http_res = perform_request(http, request)
        rescue *NET_HTTP_EXCEPTIONS => err
          if defined?(OpenSSL) && OpenSSL::SSL::SSLError === err
            raise SSLError, err
          else
            raise ConnectionFailed, err
          end
        end

        res = Response.new(request, http_res.code.to_i, Header.new, http_res.body)
        http_res.each_header do |key, value|
          res.header[key] = value
        end
        res
      end

    rescue ::Timeout::Error => err
      raise Timeout, err
    end

    private

    def net_http_connection(request)
      http = Net::HTTP.new(request.url.host, request.url.port)
      configure_ssl(http, request) if request.url.scheme == Hurley::HTTPS
      yield http
    end

    def net_http_request(request)
      http_req = Net::HTTPGenericRequest.new(
        request.verb.to_s.upcase, # request method
        !!request.body,           # is there a request body
        :head != request.verb,    # is there a response body
        request.url.request_uri,  # request uri path
        request.header,           # request headers
      )
      http_req.body_stream = request.body_io
      http_req
    end

    def perform_request(http, request)
      if :get == request.verb
        # prefer `get` to `request` because the former handles gzip (ruby 1.9)
        http.get(request.url.request_uri, request.header.to_hash)
      else
        http.request(net_http_request(request))
      end
    end

    def configure_ssl(http, request)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = self.class.default_ssl_cert_store
    end

    def self.default_ssl_cert_store
      @default_ssl_cert_store ||= begin
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        cert_store
      end
    end

    NET_HTTP_EXCEPTIONS = [
      EOFError,
      Errno::ECONNABORTED,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      Errno::EINVAL,
      Errno::ENETUNREACH,
      Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError,
      Net::ProtocolError,
      SocketError,
      Zlib::GzipFile::Error,
    ]

    NET_HTTP_EXCEPTIONS << OpenSSL::SSL::SSLError if defined?(OpenSSL)
    NET_HTTP_EXCEPTIONS << Net::OpenTimeout if defined?(Net::OpenTimeout)
  end
end
