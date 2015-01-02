require "sinatra/base"

module Hurley
  module Live
    class Server < Sinatra::Base
      set :environment, :test
      disable :logging
      disable :protection

      [:get, :post, :put, :patch, :delete, :options].each do |method|
        send(method, "/echo") do
          out = [request.request_method.downcase]

          if request.GET.any?
            out << "?#{request.GET.inspect}"
          end

          if request.POST.any?
            out << request.POST.inspect
          end

          content_type "text/plain"
          out.join(" ")
        end
      end

      get "/echo_header" do
        header = "HTTP_#{params[:name].tr('-', '_').upcase}"
        request.env.fetch(header) { 'NONE' }
      end

      get "/ssl" do
        request.secure?.to_s
      end

      get "/204" do
        status 204 # no content
      end

      error do |e|
        "#{e.class}\n#{e.to_s}\n#{e.backtrace.join("\n")}"
      end
    end

    def self.start_server(options = nil)
      require "webrick"

      options ||= {}
      port = options[:port] || 4000

      log_io = $stdout
      log_io.sync = true

      webrick_opts = {
        :Port => port, :Logger => WEBrick::Log::new(log_io),
        :AccessLog => [[log_io, "[%{X-Hurley-Connection}i] %m  %U  ->  %s %b"]],
      }

      if options[:ssl_key]
        require "openssl"
        require "webrick/https"
        webrick_opts.update(
          :SSLEnable       => true,
          :SSLPrivateKey   => OpenSSL::PKey::RSA.new(File.read(options[:ssl_key])),
          :SSLCertificate  => OpenSSL::X509::Certificate.new(File.read(options[:ssl_file])),
          :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
        )
      end

      Rack::Handler::WEBrick.run(Server, webrick_opts) do |server|
        trap(:INT)  { server.stop }
        trap(:TERM) { server.stop }
      end
    end
  end
end

if $0 == __FILE__
  Hurley::Server.run!
end
