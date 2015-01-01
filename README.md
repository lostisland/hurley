# Hurley

![](http://comicstheblog.com/wp-content/uploads/2013/10/Hurley-Run.gif)

Hurley is a ruby gem that provides a common interface for working with different
HTTP adapters.  It is an evolution of Faraday, with rethought internals.

```ruby
client = Hurley::Client.new "https://api.github.com"
client.header["blah"] = "is set on every request"
client.query["a"] = "?a is set on every request too"

client.connection = Hurley::Test.new

req = client.request :get, "/users/tater"
req.header["ABC"] = "DEF"
req.query["a"] = 1 # overrides setting above

# this yields streaming body
# but leaves response.body nil
req.on_body do |chunk|
  puts "#{chunk}"
end

res = req.run
```
