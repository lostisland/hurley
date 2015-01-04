require "openssl"

module Hurley
  class SslOptions < Struct.new(
    :verify,
    :client_cert,
    :client_key,
    :cert_store,
    :ca_file,
    :ca_path,
    :verify_mode,
    :verify_depth,
    :version,
  )

    def self.default_cert_store
      @default_cert_store ||= Hurley.mutex do
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        cert_store
      end
    end

    def verify?
      self[:verify] != false
    end

    def verify_mode
      self[:verify_mode] || begin
        verify? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end
    end

    def cert_store
      self[:cert_store] ||= self.class.default_cert_store
    end
  end
end
