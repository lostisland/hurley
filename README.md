# Hurley

![](http://comicstheblog.com/wp-content/uploads/2013/10/Hurley-Run.gif)

Hurley is a ruby gem with no runtime dependencies that provides a common
interface for working with different HTTP adapters. It is an evolution of
Faraday, with rethought internals.

Hurley revolves around three main classes: Client, Request, and Response.  A
Client sets the default properties for all HTTP requests, including the base
url, headers, and options.

```ruby
require "hurley"

# If you prefer Addressable::URI, require this too:
# This is required automatically if `Addressable::URI` is defined when Hurley
# is being loaded.
require "hurley/addressable"

client = Hurley::Client.new "https://api.github.com"
client.header[:accept] = "application/vnd.github+json"
client.query["a"] = "?a is set on every request too"

client.scheme # => "https"
client.host   # => "api.github.com"
client.port   # => 443

# See Hurley::RequestOptions in lib/hurley/options.rb
client.request_options.timeout = 3

# See Hurley::SslOptions in lib/hurley/options.rb
client.ssl_options.ca_file = "path/to/cert.crt"

# Verbs head, get, put, post, patch, delete, and options are supported.
response = client.get("users/tater") do |req|
  # These properties can be changed on a per-request basis.
  req.header[:accept] = "application/vnd.github.preview+json"
  req.query["a"] = "override!"

  req.options.timeout = 1
  req.ssl_options.ca_file = "path/to/cert.crt"

  req.verb   # => :get
  req.scheme # => "https"
  req.host   # => "api.github.com"
  req.port   # => 443
end

# You can also use Hurley class level shortcuts, which use Hurley.default_client.
response = Hurley.get("https://api.github.com/users/tater")

response.header[:content_type] # => "application/json"
response.status_code           # => 200
response.body                  # => {"id": 1, ...}
response.request               # => same as `request`

# Is this a 2xx response?
response.success?

# Is this a 3xx redirect?
response.redirection?

# Is this is a 4xx response?
response.client_error?

# Is this a 5xx response?
response.server_error?

# What kind of response is this?
response.status_type # => One of :success, :redirection, :client_error, :server_error, or :other

# Timing of the response, in ms
response.ms

# Responses automatically follow 5 redirections by default.

response.via      # Array of Request objects that redirected.
response.location # => New Request built from Location header URL.

# You can tune the number of redirections, or disable them per Client or Request.

# This client follows up to 10 redirects
client.request_options.redirection_limit = 10
client.get "/foo" do |req|
  # this specific request never follows any redirects.
  req.options.redirection_limit = 0
end
```

## Connections

By default, a `Hurley::Client` uses a `Hurley::Connection` instance to make
requests with net/http.  You can swap the connection with any object that
responds to `#call` with a Request, and returns a Response.  This will not
interrupt other client properties or callbacks.

```ruby
client = Hurley::Client.new "https://api.github.com"
client.connection = lambda do |req|
  # return a Hurley::Response!
end
```

## URLs

Hurley joins a Client endpoint with a given request URL to produce the final
URL that is requested.

```ruby
client = Hurley::Client.new "https://a:b@api.com/v1?a=1"

client.get "user" do |req|
  req.url.user     # => "a"
  req.url.password # => "b"
  req.url          # https://api.com/v1/user?a=1
end

# Absolute paths remove any path prefix
client.get "/v2/user" do |req|
  req.url.user     # => "a"
  req.url.password # => "b"
  req.url          # https://api.com/v2/user?a=1
end

client.get "user?a=2" do |req|
  req.url.user     # => "a"
  req.url.password # => "b"
  req.url          # https://api.com/v1/user?a=2
end

# Basic auth can be overridden
client.get "https://c:d@api.com/v1/user" do |req|
  req.url.user     # => "c"
  req.url.password # => "d"
  req.url          # https://api.com/v1/user?a=1
end

client.get "https://staging.api.com/v1/user" do |req|
  req.url.user     # => nil, since the host changed
  req.url.password # => nil
  req.url          # https://staging.api.com/v1/user
end
```

Hurley uses `Hurley::Query::Nested` for all query encoding and decoding by
default.  This can be changed globally, per client, or per request.  Typically
you won't create `Hurley::Query` instances manually, and will use
`Hurley::Query.parse` for parsing.

```ruby
# Nested queries

q = Hurley::Query::Nested.new(:a => [1,2], :h => {:a => 1})
q.to_query_string # => "a[]=1&a[]=2&h[a]=1"

Hurley::Query::Nested.parse(q.to_query_string)
# => #<Hurley::Query::Nested {"a"=>["1", "2"], "h"=>{"a"=>"1"}}>

# Flat queries

q = Hurley::Query::Flat.new(:a => [1,2])
q.to_query_string # => "a=1&a=2"

Hurley::Query::Flat.parse(q.to_query_string)
# => #<Hurley::Query::Nested {"a"=>["1", "2"]}>

# Change it globally.
Hurley.default = Hurley::Query::Flat

# Change it for just this client.
client = Hurley::Client.new
client.request_options.query_class = Hurley::Query::Flat

# Change it for just this request.
client.get "/foo" do |req|
  req.options.query_class = Hurley::Query::Flat
end
```

## Headers

A Client's Header is passed down to each request.  Header keys can be overridden
by the request.  Headers are stored internally in canonical form, which is
capitalized with dashes: `"Content-Type"`, for example.

See `Hurley::Header` for all of the common header keys that have symbolized
shortcuts.

```ruby
client = Hurley::Client.new "https://api.com"
client.header[:content_type] = "application/json"

# Same as:
client.header["content-type"] = "application/json"
client.header["Content-Type"] = "application/json"

client.get "/something.atom" do |req|
  # Default user agent
  req.header[:user_agent] # => "Hurley v#{Hurley::VERSION}"

  # Change a header
  req.header[:content_type] = "application/atom"
end
```

## Posting Forms

Hurley will encode form bodies for you, while setting default Content-Type and
Content-Length values as necessary.  Multipart forms are supported too, using
`Hurley::UploadIO` objects.

```ruby
# Works with HTTP verbs: post, put, and patch

# Send a=1 with Content-Type: application/x-www-form-urlencoded
client.post("/form", :a => 1)

# Send a=1 with Content-Type: text/plain
client.post("/form", {:a => 1}, "text/plain")

# Send file with Content-Type: multipart/form-data
client.post("/multipart", :file => Hurley::UploadIO.new("filename.txt", "text/plain"))
```

The default query parser (`Hurley::Query::Nested`) is used by default.  You can
change it globally, per client, or per request.  See the "URLs" section.

## Client Callbacks

Clients can define "before callbacks" that yield a Request, or "after callbacks"
that yield a Response.  Multiple callbacks of the same type are added in order.

```ruby
client.before_call do |req|
  # modify request before it's called
end

client.before_callbacks # => ["#<Proc:...>"]

client.after_call do |res|
  # modify response after it's called
end

# You can set a name to identify the callback
client.before_call :upcase do |req|
  req.body.upcase!
end

client.before_callbacks # => [:upcase]

# You can also pass an object that responds to #call and #name.
class Upcaser
  def name
    :upcaser
  end

  def call(req)
    req.body.upcase!
  end
end

client.before_call(Upcaser.new)
client.before_callbacks # => [:upcaser]
```

## Streaming the Response Body

A Request object can take a callback that receives the response body in chunks
as they are read from the socket.  Hurley connections that don't support
streaming will yield the entire response body once.

```ruby
client.get "big-file" do |req|
  req.on_body do |res, chunk|
    puts "#{res.status_code}: #{chunk}"
  end

  # This streams the body for 200 or 201 responses only:
  req.on_body(200, 201) do |res, chunk|
    puts "#{res.status_code}: #{chunk}"
  end
end
```

## Testing

Hurley includes a Test connection object for testing.  This lets you make
requests without hitting a real endpoint.

```ruby
require "hurley"
require "hurley/test"

client = Hurley::Client.new "https://api.github.com"

client.connection = Hurley::Test.new do |test|
  # Verbs head, get, put, post, patch, delete, and options are supported.
  test.get "/user" do |req|
    # req is a Hurley::Request
    # Return a Rack-compatible response.
    [200, {"Content-Type" => "application/json"}, %({"id": 1})]
  end
end

client.get("/user").body # => {"id": 1}
```

## TODO

* [ ] Backport Faraday adapters as gems
  * [x] Excon
  * [ ] Typhoeus
* [ ] Integrate into Faraday reliant gems:
  * [ ] [Sawyer](https://github.com/lostisland/sawyer)
  * [ ] [Octokit](https://github.com/octokit/octokit.rb)
  * [ ] [Elastomer](https://github.com/github/elastomer-client)
* [ ] Tomdoc all the things
* [ ] Fix allll the bugs
* [ ] Release v1.0
