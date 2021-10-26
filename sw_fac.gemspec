
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sw_fac/version"

Gem::Specification.new do |spec|
  spec.name          = "sw_fac"
  spec.version       = SwFac::VERSION
  spec.authors       = ["Angel Padilla"]
  spec.email         = ["angelpadillam@gmail.com"]

  spec.summary       = %q{Gem used to fetch the Smarter Web API}
  spec.description   = %q{Gem used to fetch the Smarter Web API for the mexican billing system (SAT), this gem was builted and is currently used by the team at mfactura.com}
  spec.homepage      = "https://github.com/angelpadilla/sw_facturacion"
  spec.license       = "MIT"

  spec.metadata['allowed_push_host'] = "https://rubygems.org"
  spec.files         = ["README.md"] + Dir["lib/**/*.*"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_dependency "nokogiri", "1.10.9"
end
