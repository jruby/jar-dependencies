# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'jars/mima'
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
      Jars::Mima.resolve_artifacts([ artifact ])
    rescue org.eclipse.aether.resolution.DependencyResolutionException
      # expected
    end

    _($stderr.string).must_include '[mima] resolving artifact org.example:example:jar:1.0'
  ensure
    $stderr = STDERR
  end
end
