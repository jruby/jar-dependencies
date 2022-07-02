# frozen_string_literal: true

require_relative 'lib/jars/version'

Gem::Specification.new do |s|
  s.name = 'jar-dependencies'

  s.version = Jars::VERSION

  s.author = 'christian meier'
  s.email = ['mkristian@web.de']
  s.summary = 'manage jar dependencies for gems'
  s.homepage = 'https://github.com/mkristian/jar-dependencies'

  s.bindir = 'exe'
  s.executables = [lock_jars = 'lock_jars']

  s.license = 'MIT'

  s.files = Dir['{lib}/**/*'] + %w[Mavenfile Rakefile Readme.md jar-dependencies.gemspec MIT-LICENSE]

  s.description = <<~TEXT
    manage jar dependencies for gems and keep track which jar was already
    loaded using maven artifact coordinates. it warns on version conflicts and
    loads only ONE jar assuming the first one is compatible to the second one
    otherwise your project needs to lock down the right version by providing a
    Jars.lock file.
  TEXT

  s.required_ruby_version = '>= 2.6'

  s.add_development_dependency 'minitest', '~> 5.10.0'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rubocop', '~> 1.31'
  s.add_development_dependency 'rubocop-performance', '~> 1.14'
  s.add_development_dependency 'rubocop-rake', '~> 0.6'
  s.add_development_dependency 'ruby-debug', '~> 0.11'
  s.add_development_dependency 'ruby-maven', ruby_maven_version = '~> 3.3'

  s.post_install_message = <<~TEXT

    if you want to use the executable #{lock_jars} then install ruby-maven gem before using #{lock_jars}

      $ gem install ruby-maven -v '#{ruby_maven_version}'

    or add it as a development dependency to your Gemfile

       gem 'ruby-maven', '#{ruby_maven_version}'

  TEXT
  s.metadata['rubygems_mfa_required'] = 'true'
end
