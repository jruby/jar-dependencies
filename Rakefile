# frozen_string_literal: true

task default: [:specs]

require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'rake/clean'

RuboCop::RakeTask.new

desc 'run specs'
task :specs do
  $LOAD_PATH << 'specs'

  Dir['specs/*_spec.rb'].each do |f|
    require File.basename(f.sub(/.rb$/, ''))
  end
end

require_relative 'lib/jars/mima/version'

MIMA_VERSION = Jars::Mima::MIMA_VERSION
SLF4J_VERSION = Jars::Mima::SLF4J_VERSION
MAVEN_CENTRAL = 'https://repo.maven.apache.org/maven2'
MIMA_DIR = 'lib/jars/mima'

MIMA_JARS = {
  "slf4j-api-#{SLF4J_VERSION}.jar" =>
    "#{MAVEN_CENTRAL}/org/slf4j/slf4j-api/#{SLF4J_VERSION}/slf4j-api-#{SLF4J_VERSION}.jar",
  "slf4j-simple-#{SLF4J_VERSION}.jar" =>
    "#{MAVEN_CENTRAL}/org/slf4j/slf4j-simple/#{SLF4J_VERSION}/slf4j-simple-#{SLF4J_VERSION}.jar",
  "jcl-over-slf4j-#{SLF4J_VERSION}.jar" =>
    "#{MAVEN_CENTRAL}/org/slf4j/jcl-over-slf4j/#{SLF4J_VERSION}/jcl-over-slf4j-#{SLF4J_VERSION}.jar",
  "context-#{MIMA_VERSION}.jar" =>
    "#{MAVEN_CENTRAL}/eu/maveniverse/maven/mima/context/#{MIMA_VERSION}/context-#{MIMA_VERSION}.jar",
  "standalone-static-uber-#{MIMA_VERSION}.jar" =>
    "#{MAVEN_CENTRAL}/eu/maveniverse/maven/mima/runtime/standalone-static-uber/#{MIMA_VERSION}/standalone-static-uber-#{MIMA_VERSION}.jar"
}

MIMA_JARS.each_key { |jar| CLEAN.include(File.join(MIMA_DIR, jar)) }

desc 'download Mima (and dependent SLF4J) jars'
task :download_jars do
  require 'fileutils'
  require 'open-uri'

  FileUtils.mkdir_p(MIMA_DIR)

  MIMA_JARS.each do |filename, url|
    target = File.join(MIMA_DIR, filename)
    if File.exist?(target)
      puts "  exists: #{target}"
      next
    end

    puts "  downloading #{filename}..."
    URI.open(url) do |remote| # rubocop:disable Security/Open
      File.open(target, 'wb') { |f| f.write(remote.read) }
    end
    puts "  saved: #{target}"
  end
end
