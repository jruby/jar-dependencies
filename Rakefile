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
MIMA_JARS = Jars::Mima::JARS
MIMA_DIR = Jars::Mima::MIMA_DIR

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
