# coding: utf-8
lib = "hurley"
lib_file = File.expand_path("../lib/#{lib}.rb", __FILE__)
File.read(lib_file) =~ /\bVERSION\s*=\s*["'](.+?)["']/
version = $1

Gem::Specification.new do |spec|
  spec.add_development_dependency "bundler", "~> 1.0"
  spec.add_development_dependency "minitest", "~> 5.5.0"
  spec.add_development_dependency "sinatra", "~> 1.4.5"
  spec.add_development_dependency "rake", "~> 10.4.2"
  spec.authors = ["Rick Olson"]
  spec.description = %q{Simple wrapper for the GitHub API}
  spec.email = ["technoweenie@gmail.com"]
  dev_null    = File.exist?("/dev/null") ? "/dev/null" : "NUL"
  git_files   = `git ls-files -z 2>#{dev_null}`
  spec.files &= git_files.split("\0") if $?.success?
  spec.test_files = Dir.glob("test/**/*.rb")
  spec.licenses = ["MIT"]
  spec.name = lib
  spec.require_paths = ["lib"]
  spec.summary = "HTTP client wrapper"
  spec.version = version
end
