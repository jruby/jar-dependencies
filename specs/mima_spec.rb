# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'jars/mima'
require 'jars/jarfile'
require 'stringio'

describe Jars::Mima do
  before do
    @env = ENV.to_h
    @properties = %w[
      org.slf4j.simpleLogger.defaultLogLevel
      org.slf4j.simpleLogger.showThreadName
      org.slf4j.simpleLogger.log.org.apache.maven
    ]
    @previous = @properties.to_h { |property| [property, ENV_JAVA[property]] }
    @properties.each { |property| ENV_JAVA[property] = nil }
    Jars.reset
  end

  after do
    @previous.each { |property, value| ENV_JAVA[property] = value } if @previous
    ENV.replace @env if @env
    Jars.reset
  end

  it 'produces debug output from debug listeners' do
    ENV['JARS_DEBUG'] = 'true'
    $stderr = StringIO.new

    artifact = Jars::GemspecArtifacts::Artifact.parse('jar org.example:example, 1.0')
    begin
      Jars::Mima.resolve_artifacts([artifact])
    rescue org.eclipse.aether.resolution.DependencyResolutionException
      # expected
    end

    _($stderr.string).must_include '[mima] resolving artifact org.example:example:jar:1.0'
  ensure
    $stderr = STDERR
  end

  it 'builds aether remote repositories from Jarfile repository declarations' do
    repos = [
      Jars::Jarfile::Repository.new('acme', 'https://acme.example/repo', false),
      Jars::Jarfile::Repository.new('acme-snap', 'https://acme.example/snapshots', true)
    ]
    remotes = Jars::Mima.remote_repositories(repos)

    _(remotes.map(&:getId)).must_equal %w[acme acme-snap]
    _(remotes.map(&:getUrl)).must_equal ['https://acme.example/repo', 'https://acme.example/snapshots']

    release = remotes[0]
    _(release.getPolicy(false).isEnabled).must_equal true  # releases enabled
    _(release.getPolicy(true).isEnabled).must_equal false  # snapshots disabled

    snapshot = remotes[1]
    _(snapshot.getPolicy(true).isEnabled).must_equal true   # snapshots enabled
    _(snapshot.getPolicy(false).isEnabled).must_equal false # releases disabled
  end
end
