# Hurley

![](http://comicstheblog.com/wp-content/uploads/2013/10/Hurley-Run.gif)

Hurley is a ruby gem that provides a common interface for working with different
HTTP adapters.  It is an evolution of Faraday, with rethought internals.

```ruby
client = Hurley::Client.new "https://api.github.com"
client.header["blah"] = "is set on every request"
client.query["a"] = "?a is set on every request too"

# not implemented
client.before_call do |req|
  # modify request before it's called
end

# not implemented
client.after_call do |res|
  # modify response after it's called
end

# change the http connection adapter
client.connection = Hurley::Test.new

req = client.request :get, "/users/tater"
req.header["ABC"] = "DEF"
req.query["a"] = 1 # overrides setting above

# this is called with the response and received bytes from the response
# leaves response.body nil
req.on_body do |res, chunk|
  puts "#{res.status_code}: #{chunk}"
end

# this is called with the response and received bytes, but only if the status is
# 200 or 201
req.on_body(200, 201) do |res, chunk|
  puts "#{res.status_code}: #{chunk}"
end

res = req.call
```
