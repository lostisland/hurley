# Hurley

![](http://comicstheblog.com/wp-content/uploads/2013/10/Hurley-Run.gif)

Hurley is a ruby gem that provides a common interface for working with different
HTTP adapters.  It is an evolution of Faraday, with rethought internals.

```ruby
client = Hurley::Client.new "https://api.github.com"
client.user_agent = "hurley v0.1"
client.header["blah"] = "is set on every request"
client.query["a"] = "?a is set on every request too"

client.adapter = Hurley::TestAdapter.new

client.on_request do |req|
  req.header["Authorization"] ||= "abc"
end

client.on_response do |res|
  res.body = JSON.parse(res.body) if res.header["Content-Type"] == "application/json"
end

# like CheckRedirect http://golang.org/pkg/net/http/#Client
client.on_redirect do |req, via|
  req.run if via.size <= 10
end

res = client.get "/users/tater" do |req|
  req.header["ABC"] = "DEF"
  req.query["a"] = 1 # overrides setting above

  # this yields streaming body
  # but leaves response.body nil
  req.on_data do |chunk|
    puts chunk
  end
end
```
