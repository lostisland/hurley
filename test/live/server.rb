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
            out << "GET: #{request.GET.inspect}"
          end

          if request.POST.any?
            out << "POST: #{request.POST.inspect}"
          end

          content_type "text/plain"
          out.join("\n")
        end
      end

      get "/204" do
        status 204 # no content
      end

      error do |e|
        "#{e.class}\n#{e.to_s}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end

if $0 == __FILE__
  Hurley::Server.run!
end
