# Hurley

![](http://comicstheblog.com/wp-content/uploads/2013/10/Hurley-Run.gif)

Hurley is a ruby gem that provides a common interface for working with different
HTTP adapters.  It is an evolution of Faraday, with rethought internals.

```ruby
client = Hurley::Client.new "https://api.github.com"
client.user_agent = "hurley v0.1"
client.header["blah"] = "is set on every request"

client.adapter = Hurley::TestAdapter.new

# like CheckRedirect http://golang.org/pkg/net/http/#Client
client.on_redirect do |req, via|
  req.run if via.size <= 10
end

req = client.build :get, "/users/tater"
req.params["a"] = 1

# follows up to 10 redirects
res = req.run
```
