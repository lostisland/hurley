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
          Response.new(request) do |res|
            http_res = perform_request(http, request, res)
            res.status_code = http_res.code.to_i
            http_res.each_header do |key, value|
              res.header[key] = value
            end

            # net/http only raises exception on 407 with ssl...?
            if res.status_code == 407
              raise ConnectionFailed, %(407 "Proxy Authentication Required")
            end
          end
        rescue *NET_HTTP_EXCEPTIONS => err
          if defined?(OpenSSL) && OpenSSL::SSL::SSLError === err
            raise SSLError, err
          else
            raise ConnectionFailed, err
          end
        end
      end

    rescue ::Timeout::Error => err
      raise Timeout, err
    end

    private

    def net_http_connection(request)
      http = if proxy = request.options.proxy
        Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password)
      else
        Net::HTTP
      end.new(request.url.host, request.url.port)

      configure_ssl(http, request) if request.url.scheme == Hurley::HTTPS

      if t = request.options.timeout
        http.read_timeout = http.open_timeout = t
      end

      if t = request.options.open_timeout
        http.open_timeout = t
      end

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

      if body = request.body_io
        http_req.body_stream = body
      end

      http_req
    end

    def perform_request(http, request, res)
      if :get == request.verb
        # prefer `get` to `request` because the former handles gzip (ruby 1.9)
        http_res = http.get(request.url.request_uri, request.header.to_hash) do |chunk|
          res.receive_body(chunk)
        end
        http_res
      else
        http_res = http.request(net_http_request(request))
        res.receive_body(http_res.body)
        http_res
      end
    end

    def configure_ssl(http, request)
      ssl = request.ssl_options
      http.use_ssl = true
      http.verify_mode = ssl.openssl_verify_mode
      http.cert_store = ssl.openssl_cert_store

      http.cert = ssl.openssl_client_cert if ssl.openssl_client_cert
      http.key = ssl.openssl_client_key if ssl.openssl_client_key
      http.ca_file = ssl.ca_file if ssl.ca_file
      http.ca_path = ssl.ca_path if ssl.ca_path
      http.verify_depth = ssl.verify_depth if ssl.verify_depth
      http.ssl_version = ssl.version if ssl.version
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
