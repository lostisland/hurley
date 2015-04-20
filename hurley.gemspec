# coding: utf-8
lib = "hurley"
lib_file = File.expand_path("../lib/#{lib}.rb", __FILE__)
File.read(lib_file) =~ /\bVERSION\s*=\s*["'](.+?)["']/
version = $1

require "yaml"
contributors = YAML.load(IO.read(File.expand_path("../contributors.yaml", __FILE__)))

Gem::Specification.new do |spec|
  spec.add_development_dependency "bundler", "~> 1.0"
  spec.authors = contributors.keys.compact
  spec.description = %q{Hurley provides a common interface for working with different HTTP adapters.}
  spec.email = contributors.values.compact
  spec.homepage = "https://github.com/lostisland/hurley"
  dev_null = File.exist?("/dev/null") ? "/dev/null" : "NUL"
  git_files = `git ls-files -z 2>#{dev_null}`
  spec.files = git_files.split("\0") if $?.success?
  spec.test_files = Dir.glob("test/**/*.rb")
  spec.licenses = ["MIT"]
  spec.name = lib
  spec.require_paths = ["lib"]
  spec.summary = "HTTP client wrapper"
  spec.version = version
end
