# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'tmpdir'
require 'jars/lock_down'

describe Jars::LockDown do
  def with_jarfile(content)
    file = File.expand_path("Jarfile.#{rand(1_000_000)}", Dir.tmpdir)
    File.write(file, content)
    ENV['JARFILE'] = file
    yield Jars::LockDown.new
  ensure
    ENV.delete('JARFILE')
    File.delete(file) if file && File.exist?(file)
  end

  # regression: issue #116 - the Jarfile was not consulted at all after 0.5.7
  it 'collects jar coordinates declared in a Jarfile' do
    with_jarfile("jar 'org.yaml:snakeyaml', '1.14'\n") do |lockdown|
      collected = {}
      lockdown.send(:append_artifacts_from_jarfile_if_any, collected)
      _(collected.values.map(&:to_gacv)).must_equal ['org.yaml:snakeyaml:1.14']
    end
  end

  it 'collects repositories and local jars declared in a Jarfile' do
    content = <<~JARFILE
      repository 'acme', 'https://acme.example/repo'
      local 'vendor/foo-1.2.jar'
      jar 'org.yaml:snakeyaml', '1.14'
    JARFILE
    with_jarfile(content) do |lockdown|
      lockdown.send(:append_artifacts_from_jarfile_if_any, {})
      _(lockdown.repositories.map(&:name)).must_equal ['acme']
      _(lockdown.local_jars.map(&:artifact_id)).must_equal ['foo']
    end
  end

  # a Jarfile entry is authoritative: it overrides the same coordinate from a gemspec
  it 'overrides a coordinate already collected from a gemspec' do
    with_jarfile("jar 'org.yaml:snakeyaml', '2.0'\n") do |lockdown|
      from_gemspec = Jars::GemspecArtifacts::Artifact.parse('jar org.yaml:snakeyaml, 1.0')
      collected = { from_gemspec.key => from_gemspec }
      lockdown.send(:append_artifacts_from_jarfile_if_any, collected)
      _(collected.values.map(&:to_gacv)).must_equal ['org.yaml:snakeyaml:2.0']
    end
  end

  it 'is a no-op when no Jarfile is present' do
    ENV['JARFILE'] = File.expand_path("does-not-exist-#{rand(1_000_000)}", Dir.tmpdir)
    lockdown = Jars::LockDown.new
    collected = {}
    lockdown.send(:append_artifacts_from_jarfile_if_any, collected)
    _(collected).must_equal({})
    _(lockdown.repositories).must_equal []
  ensure
    ENV.delete('JARFILE')
  end
end
