# frozen_string_literal: true

File.expand_path('lib', File.dirname(__FILE__)).tap do |lib|
  $LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
end

require 'jars/version'
require 'jars/mima/version'

Gem::Specification.new do |s|
  s.name = 'jar-dependencies'

  s.version = Jars::VERSION
  s.platform = 'java'

  s.author = 'christian meier'
  s.email = ['mkristian@web.de']
  s.summary = 'manage jar dependencies for gems'
  s.homepage = 'https://github.com/jruby/jar-dependencies'

  s.bindir = 'exe'
  s.executables = ['lock_jars']

  s.license = 'MIT'

  s.files = Dir['{lib}/**/*'] + %w[Mavenfile Rakefile Readme.md jar-dependencies.gemspec MIT-LICENSE]
  # explicitly require the jars
  s.files += Jars::Mima::JARS.each_key.map { File.join(Jars::Mima::MIMA_DIR, _1) }

  s.description = <<~TEXT
    manage jar dependencies for gems and keep track which jar was already
    loaded using maven artifact coordinates. it warns on version conflicts and
    loads only ONE jar assuming the first one is compatible to the second one
    otherwise your project needs to lock down the right version by providing a
    Jars.lock file.
  TEXT

  s.required_ruby_version = '>= 2.6'

  s.metadata['rubygems_mfa_required'] = 'true'
end
