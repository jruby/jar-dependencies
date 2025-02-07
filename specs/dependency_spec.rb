# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'jars/installer'

# rubocop:disable Layout/LineLength
describe Jars::Installer::Dependency do
  it 'should parse dependency line only if it is jar or pom' do
    assert_nil Jars::Installer::Dependency.new(+'something')
    assert Jars::Installer::Dependency.new(+'   org.apache.maven:maven-repository-metadata:jar:3.1.0:compile:/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar')
    assert Jars::Installer::Dependency.new(+'   org.apache.maven:maven-repository-metadata:pom:3.1.0:compile:/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar')
  end

  it 'should parse dependency line test scope' do
    dep = Jars::Installer::Dependency.new(+'   org.apache.maven:maven-repository-metadata:jar:3.1.0:test:/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :test
    _(dep.gav).must_equal 'org.apache.maven:maven-repository-metadata:3.1.0'
    _(dep.coord).must_equal 'org.apache.maven:maven-repository-metadata:jar:3.1.0'
    _(dep.path).must_equal 'org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'
    _(dep.file).must_equal '/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'
  end

  it 'should parse dependency line provided scope' do
    dep = Jars::Installer::Dependency.new(+'   org.apache.maven:maven-repository-metadata:jar:3.1.0:provided:/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :provided
    _(dep.gav).must_equal 'org.apache.maven:maven-repository-metadata:3.1.0'
    _(dep.coord).must_equal 'org.apache.maven:maven-repository-metadata:jar:3.1.0'
    _(dep.path).must_equal 'org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'
    _(dep.file).must_equal '/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'
  end

  it 'should parse dependency line runtim scope' do
    dep = Jars::Installer::Dependency.new(+'   org.apache.maven:maven-repository-metadata:jar:3.1.0:compile:/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.apache.maven:maven-repository-metadata:3.1.0'
    _(dep.coord).must_equal 'org.apache.maven:maven-repository-metadata:jar:3.1.0'
    _(dep.path).must_equal 'org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'
    _(dep.file).must_equal '/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'

    dep = Jars::Installer::Dependency.new(+'   org.apache.maven:maven-repository-metadata:jar:3.1.0:runtime:/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.apache.maven:maven-repository-metadata:3.1.0'
    _(dep.coord).must_equal 'org.apache.maven:maven-repository-metadata:jar:3.1.0'
    _(dep.path).must_equal 'org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'
    _(dep.file).must_equal '/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar'
  end

  it 'should parse pom dependency' do
    dep = Jars::Installer::Dependency.new(+'   org.apache.maven:maven-repository-metadata:pom:3.1.0:compile:/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.pom')
    _(dep.type).must_equal :pom
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.apache.maven:maven-repository-metadata:3.1.0'
    _(dep.coord).must_equal 'org.apache.maven:maven-repository-metadata:pom:3.1.0'
    _(dep.path).must_equal 'org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.pom'
    _(dep.file).must_equal '/usr/local/repository/org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.pom'
  end

  it 'should parse dependency where artifact_id has dots' do
    dep = Jars::Installer::Dependency.new(+'   org.eclipse.sisu:org.eclipse.sisu.plexus:jar:0.0.0.M2a:compile:/usr/local/repository/org/eclipse/sisu/org.eclipse.sisu.plexus/0.0.0.M2a/org.eclipse.sisu.plexus-0.0.0.M2a.jar')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.eclipse.sisu:org.eclipse.sisu.plexus:0.0.0.M2a'
    _(dep.coord).must_equal 'org.eclipse.sisu:org.eclipse.sisu.plexus:jar:0.0.0.M2a'
    _(dep.path).must_equal 'org/eclipse/sisu/org.eclipse.sisu.plexus/0.0.0.M2a/org.eclipse.sisu.plexus-0.0.0.M2a.jar'
    _(dep.file).must_equal '/usr/local/repository/org/eclipse/sisu/org.eclipse.sisu.plexus/0.0.0.M2a/org.eclipse.sisu.plexus-0.0.0.M2a.jar'
  end

  it 'should parse dependency with classifier' do
    dep = Jars::Installer::Dependency.new(+'   org.sonatype.sisu:sisu-guice:jar:no_aop:3.1.0:compile:/usr/local/repository/org/sonatype/sisu/sisu-guice/3.1.0/sisu-guice-3.1.0-no_aop.jar')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.sonatype.sisu:sisu-guice:no_aop:3.1.0'
    _(dep.coord).must_equal 'org.sonatype.sisu:sisu-guice:jar:no_aop:3.1.0'
    _(dep.path).must_equal 'org/sonatype/sisu/sisu-guice/3.1.0/sisu-guice-3.1.0-no_aop.jar'
    _(dep.file).must_equal '/usr/local/repository/org/sonatype/sisu/sisu-guice/3.1.0/sisu-guice-3.1.0-no_aop.jar'
  end

  it 'should parse dependency on windows' do
    dep = Jars::Installer::Dependency.new(+'   org.sonatype.sisu:sisu-guice:jar:no_aop:3.1.0:compile:C:\\Users\\Local\\repository\\org\\sonatype\\sisu\\sisu-guice\\3.1.0\\sisu-guice-3.1.0-no_aop.jar')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.sonatype.sisu:sisu-guice:no_aop:3.1.0'
    _(dep.coord).must_equal 'org.sonatype.sisu:sisu-guice:jar:no_aop:3.1.0'
    _(dep.path).must_equal 'org/sonatype/sisu/sisu-guice/3.1.0/sisu-guice-3.1.0-no_aop.jar'
    _(dep.file).must_equal 'C:\\Users\\Local\\repository\\org\\sonatype\\sisu\\sisu-guice\\3.1.0\\sisu-guice-3.1.0-no_aop.jar'
  end

  # these next two combine every possible oddity to try to cover all combinations (classifier, windows path, ANSI and module)

  it 'should parse dependency with module section' do
    dep = Jars::Installer::Dependency.new(+'   org.eclipse.sisu:org.eclipse.sisu.plexus:jar:no_aop:0.0.0.M2a:compile:C:\\Users\\Local\\repository\\org\\sonatype\\sisu\\org.eclipse.sisu.plexus\\0.0.0.M2a\\org.eclipse.sisu.plexus-0.0.0.M2a-no_aop.jar -- module org.sonatype.sisu.sisu-guice')
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.eclipse.sisu:org.eclipse.sisu.plexus:no_aop:0.0.0.M2a'
    _(dep.coord).must_equal 'org.eclipse.sisu:org.eclipse.sisu.plexus:jar:no_aop:0.0.0.M2a'
    _(dep.path).must_equal 'org/eclipse/sisu/org.eclipse.sisu.plexus/0.0.0.M2a/org.eclipse.sisu.plexus-0.0.0.M2a-no_aop.jar'
    _(dep.file).must_equal 'C:\\Users\\Local\\repository\\org\\sonatype\\sisu\\org.eclipse.sisu.plexus\\0.0.0.M2a\\org.eclipse.sisu.plexus-0.0.0.M2a-no_aop.jar'
  end

  it 'should parse dependency with ANSI-colored module section' do
    dep = Jars::Installer::Dependency.new(+"   org.eclipse.sisu:org.eclipse.sisu.plexus:jar:no_aop:0.0.0.M2a:compile:C:\\Users\\Local\\repository\\org\\sonatype\\sisu\\org.eclipse.sisu.plexus\\0.0.0.M2a\\org.eclipse.sisu.plexus-0.0.0.M2a-no_aop.jar\e[31m -- module org.sonatype.sisu.sisu-guice\e[m")
    _(dep.type).must_equal :jar
    _(dep.scope).must_equal :runtime
    _(dep.gav).must_equal 'org.eclipse.sisu:org.eclipse.sisu.plexus:no_aop:0.0.0.M2a'
    _(dep.coord).must_equal 'org.eclipse.sisu:org.eclipse.sisu.plexus:jar:no_aop:0.0.0.M2a'
    _(dep.path).must_equal 'org/eclipse/sisu/org.eclipse.sisu.plexus/0.0.0.M2a/org.eclipse.sisu.plexus-0.0.0.M2a-no_aop.jar'
    _(dep.file).must_equal 'C:\\Users\\Local\\repository\\org\\sonatype\\sisu\\org.eclipse.sisu.plexus\\0.0.0.M2a\\org.eclipse.sisu.plexus-0.0.0.M2a-no_aop.jar'
  end
end
# rubocop:enable Layout/LineLength
