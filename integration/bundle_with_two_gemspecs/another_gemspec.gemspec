
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'another_gemspec/version'

Gem::Specification.new do |spec|
  spec.name          = 'another_gemspec'
  spec.version       = AnotherGemspec::VERSION
  spec.authors       = ['Jason R. Clark']
  spec.email         = ['jclark@newrelic.com']
  spec.summary       = 'Wat, two gemspecs?'
  spec.description   = 'Are you crazy?'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
end
