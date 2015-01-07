require "rake"

namespace :hurley do
  desc "Start server for live tests.  HURLEY_PORT=4000"
  task :start_server do
    without_verbose do
      require File.expand_path("../test/server", __FILE__)
    end

    Hurley::Live.start_server(
      :port => (ENV["HURLEY_PORT"] || 4000).to_i,
      :ssl_key => ENV["HURLEY_SSL_KEY"],
      :ssl_file => ENV["HURLEY_SSL_FILE"],
    )
  end

  desc "Start proxy server for live tests.  HURLEY_PORT=4001, HURLEY_PROXY_AUTH=user:pass"
  task :start_proxy do
    without_verbose do
      require "webrick"
      require "webrick/httpproxy"
    end

    if found = ENV["HURLEY_PROXY_AUTH"]
      username, password = ENV["HURLEY_PROXY_AUTH"].split(":", 2)
    end

    match_credentials = lambda { |credentials|
      got_username, got_password = credentials.to_s.unpack("m*")[0].split(":", 2)
      got_username == username && got_password == password
    }

    log_io = $stdout
    log_io.sync = true

    webrick_opts = {
      :Port => (ENV["HURLEY_PORT"] || 4001).to_i,
      :Logger => WEBrick::Log::new(log_io),
      :AccessLog => [[log_io, "[%{X-Hurley-Connection}i] %m  %U  ->  %s %b"]],
      :ProxyAuthProc => lambda { |req, res|
        if username
          type, credentials = req.header["proxy-authorization"].first.to_s.split(/\s+/, 2)
          unless "Basic" == type && match_credentials.call(credentials)
            res["proxy-authenticate"] = %{Basic realm="testing"}
            raise WEBrick::HTTPStatus::ProxyAuthenticationRequired
          end
        end
      }
    }

    proxy = WEBrick::HTTPProxyServer.new(webrick_opts)

    trap(:TERM) { proxy.shutdown }
    trap(:INT) { proxy.shutdown }

    proxy.start
  end

  desc "Generate test certs for testing Hurley with SSL"
  task :generate_certs do
    without_verbose do
      require "openssl"
      require "fileutils"
    end

    $shell = !!ENV["IN_SHELL"]

    # Adapted from WEBrick::Utils. Skips cert extensions so it
    # can be used as a CA bundle
    def create_self_signed_cert(bits, cn, comment)
      rsa = OpenSSL::PKey::RSA.new(bits)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      name = OpenSSL::X509::Name.new(cn)
      cert.subject = name
      cert.issuer = name
      cert.not_before = Time.now
      cert.not_after = Time.now + (365*24*60*60)
      cert.public_key = rsa.public_key
      cert.sign(rsa, OpenSSL::Digest::SHA1.new)
      return [cert, rsa]
    end

    def write(file, contents, env_var)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, "w") do |f|
        f.puts(contents)
      end
      puts %(export #{env_var}="#{file}") if $shell
    end


    # One cert / CA for ease of testing when ignoring verification
    cert, key = create_self_signed_cert(1024, [["CN", "localhost"]], "Hurley Test CA")
    write "tmp/hurley-cert.key", key,  "HURLEY_SSL_KEY"
    write "tmp/hurley-cert.crt", cert, "HURLEY_SSL_FILE"

    # And a second CA to prove that verification can fail
    cert, key = create_self_signed_cert(1024, [["CN", "real-ca.com"]], "A different CA")
    write "tmp/hurley-different-ca-cert.key", key,  "HURLEY_SSL_KEY_ALT"
    write "tmp/hurley-different-ca-cert.crt", cert, "HURLEY_SSL_FILE_ALT"
  end
end

def without_verbose
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end
