# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'jars/installer'
require 'fileutils'
require 'rubygems/specification'

module Jars
  class Installer
    def do_install(vendor, write)
      @vendor = vendor
      @write = write
    end

    attr_reader :vendor, :write
  end
end
describe Jars::Installer do
  let(:file) { File.join(pwd, 'deps.txt') }

  let(:pwd) { File.dirname(File.expand_path(__FILE__)) }

  let(:dir) { File.join(pwd, '..', 'pkg', 'tmp') }

  let(:jars) { File.join(dir, 'test_jars.rb') }

  let(:example_spec) { File.join(pwd, '..', 'example', 'example.gemspec') }

  before do
    FileUtils.rm_rf(dir)
    FileUtils.mkdir_p(dir)
  end

  it 'loads dependencies from maven' do
    deps = Jars::Installer.load_from_maven(file)
    _(deps.size).must_equal 45
    deps.each { |d| _(d).must_be_kind_of(Jars::Installer::Dependency) }
  end

  it 'generates non-vendored require-file' do
    deps = Jars::Installer.load_from_maven(file)
    Jars::Installer.write_require_jars(deps, jars)
    File.read(jars).each_line do |line|
      _(line).must_match(/^\s{2}require(_jar)?\s'.+'$/) if line.size > 30 && !line.match(/^#/)
    end
    _( Dir[File.join(dir, '**')].size ).must_equal 1
  end

  it 'generates vendored require-file' do
    deps = Jars::Installer.load_from_maven(file)
    Jars::Installer.write_require_jars(deps, jars)
    Jars::Installer.vendor_jars(deps, dir)
    File.read(jars).each_line do |line|
      _(line).must_match(/^\s{2}require(_jar)?\s'.+'$/) if line.size > 30 && !line.match(/^#/)
    end
    _( Dir[File.join(dir, '**', '*.jar')].size ).must_equal 45
  end

  it 'just skips install_jars and vendor_jars if there are no requirements' do
    jar = Jars::Installer.new
    jar.install_jars
    # vendor method is a mocked method
    _(jar.vendor).must_be_nil
    jar.vendor_jars
    # vendor method is a mocked method
    _(jar.vendor).must_be_nil
  end

  it 'just skips install_jars and vendor_jars if platform is not java' do
    spec = Gem::Specification.load(example_spec)
    spec.platform = 'ruby'
    jar = Jars::Installer.new(spec)
    jar.install_jars
    # vendor method is a mocked method
    _(jar.vendor).must_be_nil
    jar.vendor_jars
    # vendor method is a mocked method
    _(jar.vendor).must_be_nil
  end

  it 'does install_jars and vendor_jars' do
    ENV['JARS_VENDOR'] = nil
    jar = Jars::Installer.new(example_spec)
    jar.install_jars
    # vendor method is a mocked method
    assert_nil jar.vendor
    ENV['JARS_VENDOR'] = 'false'
    jar.vendor_jars
    # vendor method is a mocked method
    assert_nil jar.vendor
    ENV['JARS_VENDOR'] = 'true'
    jar.vendor_jars
    # vendor method is a mocked method
    _(jar.vendor).must_equal 'lib'
    java.lang.System.set_property('jars.vendor', 'false')
    jar.vendor_jars
    # vendor method is a mocked method
    assert_nil jar.vendor
  end

  it 'installs dependencies ' do
    ENV['JARS_HOME'] = dir
    Jars.reset
    jar = Jars::Installer.new(example_spec)
    result = jar.send :install_dependencies
    _(result.size).must_equal 30
    result.each do |d|
      _(d.type).must_equal :jar
      _(d.scope).must_equal :runtime
    end
    ENV['JARS_HOME'] = nil
  end
end
