# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongoid/versioning/version'

Gem::Specification.new do |spec|
  spec.name          = "mongoid-versioning"
  spec.version       = Mongoid::Versioning::VERSION
  spec.authors       = ["Durran Jordan", "Josef Šimánek"]
  spec.email         = ["durran@gmail.com", "retro@ballgag.cz"]
  spec.description   = %{Mongoid-versioning supports simple versioning through inclusion of the Mongoid::Versioning module.}
  spec.summary       = %q{Versioned documents}
  spec.homepage      = "https://github.com/simi/mongoid-versioning"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "mongoid", '> 3'
  spec.add_development_dependency "rspec", '~> 2.11'
end
