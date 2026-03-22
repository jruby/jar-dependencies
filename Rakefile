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

# URL and SHA-1 checksum (as published on Maven Central) for each jar
MIMA_JARS = {
  "slf4j-api-#{SLF4J_VERSION}.jar" => {
    url: "#{MAVEN_CENTRAL}/org/slf4j/slf4j-api/#{SLF4J_VERSION}/slf4j-api-#{SLF4J_VERSION}.jar",
    sha1: '6c62681a2f655b49963a5983b8b0950a6120ae14'
  },
  "slf4j-simple-#{SLF4J_VERSION}.jar" => {
    url: "#{MAVEN_CENTRAL}/org/slf4j/slf4j-simple/#{SLF4J_VERSION}/slf4j-simple-#{SLF4J_VERSION}.jar",
    sha1: 'a41f9cfe6faafb2eb83a1c7dd2d0dfd844e2a936'
  },
  "jcl-over-slf4j-#{SLF4J_VERSION}.jar" => {
    url: "#{MAVEN_CENTRAL}/org/slf4j/jcl-over-slf4j/#{SLF4J_VERSION}/jcl-over-slf4j-#{SLF4J_VERSION}.jar",
    sha1: 'd877e195a05aca4a2f1ad2ff14bfec1393af4b5e'
  },
  "context-#{MIMA_VERSION}.jar" => {
    url: "#{MAVEN_CENTRAL}/eu/maveniverse/maven/mima/context/#{MIMA_VERSION}/context-#{MIMA_VERSION}.jar",
    sha1: '72aa4d9ccef7a329f473e43752ec863c5194c72c'
  },
  "standalone-static-uber-#{MIMA_VERSION}.jar" => {
    url: "#{MAVEN_CENTRAL}/eu/maveniverse/maven/mima/runtime/standalone-static-uber/#{MIMA_VERSION}/standalone-static-uber-#{MIMA_VERSION}.jar",
    sha1: '43666099e6eb31610f9d3b146811479dd3e4aef1'
  }
}.freeze

MIMA_JARS.each_key { |jar| CLEAN.include(File.join(MIMA_DIR, jar)) }

desc 'download Mima (and dependent SLF4J) jars'
task :download_jars do
  require 'fileutils'
  require 'open-uri'
  require 'digest/sha1'

  FileUtils.mkdir_p(MIMA_DIR)

  MIMA_JARS.each do |filename, info|
    target = File.join(MIMA_DIR, filename)
    if File.exist?(target)
      verify_checksum(target, info[:sha1])
      puts "  exists: #{target}"
      next
    end

    puts "  downloading #{filename}..."
    URI.open(info[:url]) do |remote| # rubocop:disable Security/Open
      File.open(target, 'wb') { |f| f.write(remote.read) }
    end
    verify_checksum(target, info[:sha1])
    puts "  saved: #{target}"
  end
end

def verify_checksum(path, expected_sha1)
  actual = Digest::SHA1.file(path).hexdigest
  return if actual == expected_sha1

  File.delete(path)
  raise "SHA-1 mismatch for #{path}:\n" \
        "  expected: #{expected_sha1}\n" \
        "  actual:   #{actual}"
end
