# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'yaml'

module Helper
  def self.prepare!(array)
    exclusions = %w[
      org/yaml/snakeyaml/snakeyaml.jar
      org/jruby/dirgra/dirgra.jar
      org/jruby/yecht/yecht.jar
    ]
    result = array.collect do |a|
      a.sub(/\.jar.*$/, '.jar')
       .sub(/-native.jar$/, '.jar')
       .sub(/-[^-]+$/, '.jar')
       .sub(%r{[^/]+/([^/]+)$}, '\1')
       .sub(/^.*META-INF.jruby.home.lib.ruby.s....../, '')
       .sub(/.*#{Jars.home}./, '')
       .sub(/.*#{Jars.local_maven_repo}./, '')
       .sub(/.*repository./, '') # make sure we trim this
    end - exclusions
    # omit ruby-maven jars
    result.delete_if { |c| c.include?('ruby-maven') }
    result.uniq.sort
  end

  def self.reduce(big, small)
    (prepare!(big) - prepare!(small)).uniq.sort.to_yaml
  end

  def self.prepare(array)
    prepare!(array).to_yaml
  end
end

describe Jars::Classpath do
  let(:deps) { File.join(pwd, 'deps.txt') }

  let(:pwd) { File.dirname(File.expand_path(__FILE__)) }

  let(:jars_lock) { File.join(pwd, 'Jars.lock') }

  let(:jars_no_jline_lock) { File.join(pwd, 'Jars_no_jline.lock') }

  let(:example_spec) { File.join(pwd, '..', 'example', 'example.gemspec') }

  let(:example_expected) do
    ['com/fasterxml/jackson/core/jackson-databind/2.5.1/jackson-databind-2.5.1.jar',
     'io/dropwizard/dropwizard-jackson/0.8.0-rc5/dropwizard-jackson-0.8.0-rc5.jar',
     'com/fasterxml/classmate/1.0.0/classmate-1.0.0.jar',
     'io/dropwizard/dropwizard-util/0.8.0-rc5/dropwizard-util-0.8.0-rc5.jar',
     'com/fasterxml/jackson/module/jackson-module-afterburner/2.5.1/jackson-module-afterburner-2.5.1.jar',
     'com/fasterxml/jackson/datatype/jackson-datatype-guava/2.5.1/jackson-datatype-guava-2.5.1.jar',
     'org/bouncycastle/bcpkix-jdk15on/1.49/bcpkix-jdk15on-1.49.jar',
     'org/bouncycastle/bcprov-jdk15on/1.49/bcprov-jdk15on-1.49.jar',
     'com/google/code/findbugs/jsr305/3.0.0/jsr305-3.0.0.jar',
     'org/jboss/logging/jboss-logging/3.1.3.GA/jboss-logging-3.1.3.GA.jar',
     'io/dropwizard/metrics/metrics-core/3.1.0/metrics-core-3.1.0.jar',
     'org/slf4j/jcl-over-slf4j/1.7.10/jcl-over-slf4j-1.7.10.jar',
     'org/slf4j/log4j-over-slf4j/1.7.10/log4j-over-slf4j-1.7.10.jar',
     'org/hibernate/hibernate-validator/5.1.3.Final/hibernate-validator-5.1.3.Final.jar',
     'ch/qos/logback/logback-core/1.1.2/logback-core-1.1.2.jar',
     'com/fasterxml/jackson/core/jackson-core/2.5.1/jackson-core-2.5.1.jar',
     'org/slf4j/jul-to-slf4j/1.7.10/jul-to-slf4j-1.7.10.jar',
     'io/dropwizard/dropwizard-logging/0.8.0-rc5/dropwizard-logging-0.8.0-rc5.jar',
     'org/glassfish/javax.el/3.0.0/javax.el-3.0.0.jar',
     'io/dropwizard/metrics/metrics-logback/3.1.0/metrics-logback-3.1.0.jar',
     'com/google/guava/guava/18.0/guava-18.0.jar',
     'com/fasterxml/jackson/datatype/jackson-datatype-jdk7/2.5.1/jackson-datatype-jdk7-2.5.1.jar',
     'io/dropwizard/dropwizard-validation/0.8.0-rc5/dropwizard-validation-0.8.0-rc5.jar',
     'javax/validation/validation-api/1.1.0.Final/validation-api-1.1.0.Final.jar',
     'ch/qos/logback/logback-classic/1.1.2/logback-classic-1.1.2.jar',
     'com/google/protobuf/protobuf-java/2.2.0/protobuf-java-2.2.0-lite.jar',
     'com/fasterxml/jackson/core/jackson-annotations/2.5.0/jackson-annotations-2.5.0.jar',
     'org/slf4j/slf4j-api/1.7.7/slf4j-api-1.7.7.jar',
     'com/fasterxml/jackson/datatype/jackson-datatype-joda/2.5.1/jackson-datatype-joda-2.5.1.jar',
     'org/eclipse/jetty/jetty-util/9.2.9.v20150224/jetty-util-9.2.9.v20150224.jar']
  end

  let(:expected_with_bc) { example_expected + bouncycastle }

  let(:lock_expected) do
    ['org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar',
     'com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar',
     'org/apache/httpcomponents/httpclient/4.2.3/httpclient-4.2.3.jar',
     'org/sonatype/sisu/sisu-guice/3.1.0/sisu-guice-no_aop-3.1.0.jar',
     '${java.home}/../lib/tools.jar',
     'org/sonatype/plexus/plexus-cipher/1.4/plexus-cipher-1.4.jar']
  end

  let(:lock_expected_runtime) do
    ['org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar',
     'org/sonatype/sisu/sisu-guice/3.1.0/sisu-guice-no_aop-3.1.0.jar',
     '${java.home}/../lib/tools.jar',
     'org/sonatype/plexus/plexus-cipher/1.4/plexus-cipher-1.4.jar']
  end

  let(:lock_expected_test) do
    ['org/apache/maven/maven-repository-metadata/3.1.0/maven-repository-metadata-3.1.0.jar',
     'com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar',
     'org/apache/httpcomponents/httpclient/4.2.3/httpclient-4.2.3.jar',
     'org/sonatype/sisu/sisu-guice/3.1.0/sisu-guice-no_aop-3.1.0.jar',
     '${java.home}/../lib/tools.jar',
     'org/slf4j/slf4j-api/1.6.2/slf4j-api-1.6.2.jar',
     'org/sonatype/plexus/plexus-cipher/1.4/plexus-cipher-1.4.jar']
  end

  let(:bc_prov) { ['org/bouncycastle/bcprov-jdk15on/1.49/bcprov-jdk15on-1.49.jar'] }

  let(:bc_pkix) { ['org/bouncycastle/bcpkix-jdk15on/1.49/bcpkix-jdk15on-1.49.jar'] }

  let(:bouncycastle) { bc_pkix + bc_prov + ['org/slf4j/slf4j-api/1.7.7/slf4j-api-1.7.7.jar'] }

  subject { Jars::Classpath.new(example_spec) }

  after do
    ENV_JAVA['jars.quiet'] = nil
    Jars.reset
  end

  it 'resolves classpath from gemspec' do
    ENV_JAVA['jars.quiet'] = 'true'
    Dir.chdir(File.dirname(example_spec)) do
      _(Helper.prepare(subject.classpath)).must_equal Helper.prepare(example_expected)

      _(Helper.prepare(subject.classpath(:compile))).must_equal Helper.prepare(
        expected_with_bc + ['org/slf4j/slf4j-simple/1.7.7/slf4j-simple-1.7.7.jar']
      )

      _(Helper.prepare(subject.classpath(:test))).must_equal Helper.prepare(expected_with_bc + [
        'junit/junit/4.12/junit-4.12.jar',
        'org/slf4j/slf4j-simple/1.7.7/slf4j-simple-1.7.7.jar',
        'org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar'
      ])

      _(Helper.prepare(subject.classpath(:runtime))).must_equal Helper.prepare(example_expected)
    end
  end

  it 'resolves classpath_string from gemspec' do
    ENV_JAVA['jars.quiet'] = 'true'
    Dir.chdir(File.dirname(example_spec)) do
      _(Helper.prepare(subject.classpath_string.split(File::PATH_SEPARATOR)))
        .must_equal Helper.prepare(example_expected)

      _(Helper.prepare(subject.classpath_string(:compile).split(File::PATH_SEPARATOR)))
        .must_equal Helper.prepare(
          expected_with_bc + ['org/slf4j/slf4j-simple/1.7.7/slf4j-simple-1.7.7.jar']
        )

      _(Helper.prepare(subject.classpath_string(:test).split(File::PATH_SEPARATOR)))
        .must_equal Helper.prepare(expected_with_bc + [
          'junit/junit/4.12/junit-4.12.jar',
          'org/slf4j/slf4j-simple/1.7.7/slf4j-simple-1.7.7.jar',
          'org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar'
        ])

      _(Helper.prepare(subject.classpath_string(:runtime).split(File::PATH_SEPARATOR)))
        .must_equal Helper.prepare(example_expected)
    end
  end

  it 'requires classpath from gemspec' do
    # TODO: see not to require compile scope for 9k

    skip('TODO just use some empty jars for this spec')

    old = $CLASSPATH.to_a

    # sometimes the $CLASSPATH can already have BC jars
    # and it is not possible to unload entries from $CLASSPATH
    expected = if old.detect { |c| c.include?('bcprov-jdk15on') }
                 if old.detect { |c| c.include?('bcpkix-jdk15on') }
                   []
                 else
                   bc_pkix
                 end
               elsif old.detect { |c| c.include?('bcpkix-jdk15on') }
                 bc_prov
               else
                 bouncycastle
               end

    subject.require(:runtime)

    _(Helper.reduce($CLASSPATH.to_a, old)).must_equal Helper.prepare(expected)

    expected += example_expected
    subject.require(:compile)
    _(Helper.reduce($CLASSPATH.to_a, old)).must_equal Helper.prepare(expected)

    expected << 'junit/junit/4.1/junit-4.1.jar'
    subject.require(:test)
    _(Helper.reduce($CLASSPATH.to_a, old)).must_equal Helper.prepare(expected)
  end

  it 'processes Jars.lock if exists' do
    subject.instance_variable_set(:@deps, jars_lock)

    _(Helper.prepare(subject.classpath)).must_equal Helper.prepare(lock_expected_runtime)
    _(Helper.prepare(subject.classpath(:compile))).must_equal Helper.prepare(lock_expected)

    _(Helper.prepare(subject.classpath(:test))).must_equal Helper.prepare(lock_expected_test)

    _(Helper.prepare(subject.classpath(:runtime))).must_equal Helper.prepare(lock_expected_runtime)
  end

  it 'processes Jars.lock and block loading of jars' do
    subject.instance_variable_set(:@deps, jars_no_jline_lock)

    subject.require

    require_jar 'example', 'example', '1'
    _($CLASSPATH.detect { |c| c.include?('example') }).must_be_nil
  end
end
