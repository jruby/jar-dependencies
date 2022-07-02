# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'jars/maven_exec'
require 'fileutils'
require 'stringio'

describe Jars::MavenExec do
  let(:pwd) { File.dirname(File.expand_path(__FILE__)) }

  let(:example_spec) { File.join(pwd, '..', 'example', 'example.gemspec') }
  let(:spec_with_require_relative) do
    File.join(pwd, 'example', 'gem_with_require_relative', 'gem_with_require_relative.gemspec')
  end

  after do
    Jars.reset
  end

  it 'should not warn if gemspec contains require_relative' do
    Dir.chdir File.dirname(spec_with_require_relative) do
      $stderr = StringIO.new
      Jars::MavenExec.new
      $stderr.string.must_equal ''
    ensure
      $stderr = STDERR
    end
  end

  it 'finds the gemspec file when the Gem::Specification.spec_file is wrong' do
    spec = Dir.chdir(File.dirname(example_spec)) do
      eval(File.read(example_spec)) # rubocop:disable Security/Eval
    end

    spec.loaded_from = spec.spec_file
    # mimic bundler case
    FileUtils.rm_f(spec.spec_file)
    def spec.gem_dir=(dir)
      @d = dir
    end

    def spec.gem_dir
      @d
    end
    spec.gem_dir = File.dirname(example_spec)
    # now test finding the gemspec file
    jar = Jars::MavenExec.new(spec)
    jar.instance_variable_get(:@basedir).must_equal File.expand_path(spec.gem_dir)
    jar.instance_variable_get(:@specfile).must_equal File.expand_path(example_spec)
  end
end
