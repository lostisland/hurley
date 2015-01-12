require "openssl"
require "securerandom"

module Hurley
  class RequestOptions < Struct.new(
    # Integer or Fixnum number of seconds to wait for one block to be read.
    :timeout,

    # Integer or Fixnum number of seconds to wait for the connection to open.
    :open_timeout,

    # String boundary to use for multipart request bodies.
    :boundary,

    # A SocketBinding specifying the host and/or port of the local client
    # socket.
    :bind,

    # Hurley::Url instance of an HTTP Proxy address.
    :proxy,

    # Integer limit on the number of redirects that are automatically followed.
    # Set to < 1 to disable automatic redirections. Default: 5
    :redirection_limit,

    # Hurley::Query subclass to use for query objects.  Defaults to
    # Hurley::Query.default.
    :query_class,
  )

    def timeout_ms
      self[:timeout].to_i * 1000
    end

    def open_timeout_ms
      self[:open_timeout].to_i * 1000
    end

    def redirection_limit
      self[:redirection_limit] ||= 5
    end

    def bind=(b)
      self[:bind] = SocketBinding.parse(b)
    end

    def build_form(body)
      query_class.new(body).to_form(self)
    end

    def boundary
      self[:boundary] || "Hurley-#{SecureRandom.hex}"
    end

    def query_class
      self[:query_class] ||= Query.default
    end
  end

  class SslOptions < Struct.new(
    # Boolean that specifies whether to skip SSL verification.
    :skip_verification,

    # Sets the maximum depth for the certificate chain verification.
    :verify_depth,

    # String path of a CA certification file in PEM format.
    :ca_file,

    # String path of a CA certification directory containing certifications in PEM format.
    :ca_path,

    # String client cert contents.
    :client_cert,

    # String path to client certificate.
    :client_cert_path,

    # String private key contents.
    :private_key,

    # String path to private key.
    :private_key_path,

    # String pass for the private key
    :private_key_pass,

    # An OpenSSL::X509::Certificate object for a client certificate.
    :openssl_client_cert,

    # An OpenSSL::PKey::RSA or OpenSSL::PKey::DSA object.
    :openssl_client_key,

    # The X509::Store to verify peer certificate.
    :openssl_cert_store,

    # Sets the SSL version.  See OpenSSL::SSL::SSLContext::METHODS for available
    # versions.
    :version,
  )

    def skip_verification?
      self[:skip_verification]
    end

    def openssl_verify_mode
      skip_verification ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
    end

    def openssl_client_cert
      self[:openssl_client_cert] ||= begin
        cert_contents = self[:client_cert] || (self[:client_cert_path] && IO.read(self[:client_cert_path]))
        return unless cert_contents
        OpenSSL::X509::Certificate.new(cert_contents)
      end
    end

    def openssl_cert_store
      self[:openssl_cert_store] ||= OpenSSL::X509::Store.new.tap do |store|
        store.set_default_paths
      end
    end

    def openssl_private_key
      @openssl_private_key ||= begin
        pkey = if pkey_path = self[:private_key_path]
          File.read(pkey_path)
        else
          self[:private_key]
        end

        return unless pkey

        if OpenSSL::PKey.respond_to?(:read)
          OpenSSL::PKey.read(pkey, self[:private_key_pass])
        else
          OpenSSL::PKey::RSA.new(pkey, self[:private_key_pass])
        end
      end
    end
  end

  class SocketBinding < Struct.new(:host, :port)
    def self.parse(bind)
      h, p = bind.to_s.split(":", 2)
      p = p.to_i
      new(h, p.zero? ? nil : p)
    end
  end
end
