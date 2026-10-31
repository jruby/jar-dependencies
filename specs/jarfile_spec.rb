# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'tmpdir'
require 'jars/jarfile'

describe Jars::Jarfile do
  def jarfile(content)
    file = File.expand_path("Jarfile.#{rand(1_000_000)}", Dir.tmpdir)
    File.write(file, content)
    Jars::Jarfile.load(file)
  ensure
    File.delete(file) if file && File.exist?(file)
  end

  it 'reads jar and pom coordinates' do
    jf = jarfile(<<~JARFILE)
      jar 'org.yaml:snakeyaml', '1.14'
      pom 'org.apache.camel:camel-core', '2.9.2'
    JARFILE
    _(jf.artifacts.map(&:to_gacv)).must_equal ['org.yaml:snakeyaml:1.14',
                                               'org.apache.camel:camel-core:2.9.2']
    _(jf.artifacts.map(&:type)).must_equal %w[jar pom]
  end

  it 'reads a single-string coordinate (group:artifact:version)' do
    jf = jarfile("jar 'org.yaml:snakeyaml:1.14'\n")
    a = jf.artifacts.first
    _(a.group_id).must_equal 'org.yaml'
    _(a.artifact_id).must_equal 'snakeyaml'
    _(a.version).must_equal '1.14'
    _(a.classifier).must_be_nil
  end

  it 'reads a single-string coordinate with classifier (group:artifact:version:classifier)' do
    jf = jarfile("jar 'org.foo:bar:1.0:sources'\n")
    a = jf.artifacts.first
    _(a.to_gacv).must_equal 'org.foo:bar:sources:1.0'
    _(a.classifier).must_equal 'sources'
  end

  it 'reads a classifier in the two-arg form (group:artifact:classifier, version)' do
    jf = jarfile("jar 'org.foo:bar:jdk15', '1.0'\n")
    a = jf.artifacts.first
    _(a.classifier).must_equal 'jdk15'
    _(a.version).must_equal '1.0'
  end

  it 'reads the three-arg form (group, artifact, version)' do
    jf = jarfile("jar 'org.foo', 'bar', '1.0'\n")
    a = jf.artifacts.first
    _(a.group_id).must_equal 'org.foo'
    _(a.artifact_id).must_equal 'bar'
    _(a.version).must_equal '1.0'
  end

  it 'applies the :scope option' do
    jf = jarfile("jar 'org.foo:bar', '1.0', :scope => 'test'\n")
    _(jf.artifacts.first.scope).must_equal 'test'
  end

  it 'applies the :classifier option' do
    jf = jarfile("jar 'org.foo:bar', '1.0', :classifier => 'jdk15'\n")
    _(jf.artifacts.first.classifier).must_equal 'jdk15'
  end

  it 'applies inline :exclusions (strings and arrays)' do
    jf = jarfile("jar 'org.foo:bar', '1.0', :exclusions => ['x:y', ['p', 'q']]\n")
    ex = jf.artifacts.first.exclusions
    _(ex.map(&:to_s)).must_equal ['x:y', 'p:q']
  end

  it 'applies an enclosing scope block only to its declarations' do
    jf = jarfile(<<~JARFILE)
      scope :test do
        jar 'org.foo:bar', '1.0'
      end
      jar 'org.foo:baz', '2.0'
    JARFILE
    _(jf.artifacts.map(&:scope)).must_equal ['test', nil]
  end

  it 'lets an inline :scope override the enclosing scope block' do
    jf = jarfile(<<~JARFILE)
      scope :test do
        jar 'org.foo:bar', '1.0', :scope => 'provided'
      end
    JARFILE
    _(jf.artifacts.first.scope).must_equal 'provided'
  end

  it 'reads scope and classifier from a jar block' do
    jf = jarfile(<<~JARFILE)
      jar 'org.foo:bar', '1.0' do
        scope 'test'
        classifier 'sources'
      end
    JARFILE
    a = jf.artifacts.first
    _(a.scope).must_equal 'test'
    _(a.classifier).must_equal 'sources'
  end

  it 'reads exclusions declared inside a jar block' do
    jf = jarfile(<<~JARFILE)
      jar 'org.foo:bar', '1.0' do
        exclusion 'group:a1'
        exclusion 'group', 'a2'
      end
    JARFILE
    _(jf.artifacts.first.exclusions.map(&:to_s)).must_equal ['group:a1', 'group:a2']
  end

  it 'combines inline :exclusions with a block exclusion' do
    jf = jarfile(<<~JARFILE)
      jar 'dsa:dsa', '12', :exclusions => ['group:b1', ['group', 'b2']] do
        exclusion 'group:b3'
      end
    JARFILE
    _(jf.artifacts.first.exclusions.map(&:to_s)).must_equal ['group:b1', 'group:b2', 'group:b3']
  end

  it 'collects repositories, source alias and snapshot repositories' do
    jf = jarfile(<<~JARFILE)
      source "http://1.2.3.4/artifactory/"
      repository 'takari', "http://takari.io/repo"
      snapshot_repository 'tesla', "http://tesla.io/snapshots"

      jar 'junit:junit', '4.11'
    JARFILE
    _(jf.repositories.map { |r| [r.name, r.url, r.snapshot] }).must_equal [
      ['http://1.2.3.4/artifactory/', 'http://1.2.3.4/artifactory/', false],
      ['takari', 'http://takari.io/repo', false],
      ['tesla', 'http://tesla.io/snapshots', true]
    ]
    _(jf.artifacts.map(&:to_gacv)).must_equal ['junit:junit:4.11']
  end

  it 'records a local jar as a system-scoped entry with derived coordinates' do
    jf = jarfile("local 'vendor/foo-1.2.jar'\n")
    lj = jf.local_jars.first
    _(lj.group_id).must_equal 'ruby.maven-tools.jar'
    _(lj.artifact_id).must_equal 'foo'
    _(lj.version).must_equal '1.2'
    _(lj.path).must_match(%r{/vendor/foo-1\.2\.jar$})
  end

  it 'emits a system-scoped lock entry for a local jar' do
    jf = jarfile("local 'vendor/foo-1.2.jar'\n")
    entry = jf.local_jars.first.to_lock_entry
    _(entry).must_match(%r{^ruby\.maven-tools\.jar:foo:1\.2:system:.*/vendor/foo-1\.2\.jar$})
  end

  it 'treats jruby as a no-op (deprecated) and still reads other declarations' do
    jf = jarfile(<<~JARFILE)
      jruby '9.4.0.0'
      jar 'org.foo:bar', '1.0'
    JARFILE
    _(jf.artifacts.map(&:to_gacv)).must_equal ['org.foo:bar:1.0']
    _(jf.local_jars).must_equal []
  end

  it 'supports the full nested exclusions DSL (maven-tools parity)' do
    jf = jarfile(<<~JARFILE)
      jar 'asd:asd:123' do
        scope 'test'
        classifier 'source'
        exclusions 'group:a1', ['group', 'a2'] do
          exclusion 'group', 'a3'
          exclusion :artifact_id => 'a4', :group_id => 'group'
          exclusion 'group:a5'
          exclusion 'group' do
            artifact_id 'a6'
          end
          exclusion do
            group_id 'group'
            artifact_id 'a7'
          end
        end
      end
    JARFILE
    a = jf.artifacts.first
    _(a.scope).must_equal 'test'
    _(a.classifier).must_equal 'source'
    _(a.exclusions.map(&:to_s)).must_equal %w[group:a1 group:a2 group:a3 group:a4 group:a5 group:a6 group:a7]
  end
end
