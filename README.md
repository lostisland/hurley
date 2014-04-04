# Hurley

![](http://comicstheblog.com/wp-content/uploads/2013/10/Hurley-Run.gif)

Hurley is a ruby gem that provides a common interface for working with different
HTTP adapters.  It is an evolution of Faraday, with rethought internals.

```ruby
client = Hurley::Connection.new "https://api.github.com"
client.user_agent = "hurley v0.1"

client.adapter = Hurley::TestAdapter.new

client.on_request do |req|
  req.user_agent += " modified"
end

# demonstrate a potential caching middleware
client.on_request do |req|
  # skip request if a Faraday::Response is returned
  res = Cache.find(req)
end

# potential redirect following
client.on_response do |res|
  # redo all `on_response` callbacks with returned Faraday::Response
  res.follow_redirect if res.status == 301
end

# potential retries
client.on_response do |res|
  # redo all `on_response` callbacks with returned Faraday::Response
  res.retry if res.status == 500
end

client.on_response do |res|
  res.body = JSON.parse(res.body)
end

req = client.build :get, "/users/tater"
req.params["a"] = 1

res = req.run
```
