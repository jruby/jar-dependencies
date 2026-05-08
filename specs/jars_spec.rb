# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'stringio'
describe Jars do
  before do
    @env = ENV.to_h
    # helpful when debugging
    Jars.reset
  end

  after do
    Jars.reset
    ENV.clear
    ENV.replace @env # restore ENV
  end

  it 'extract property' do
    ENV['SOME_JARS_HOME'] = 'bla'
    _(Jars.to_prop('some_jars_home')).must_equal 'bla'
    if defined? JRUBY_VERSION
      java.lang.System.set_property('some.jars.home', 'blabla')
      _(Jars.to_prop('some_jars_home')).must_equal 'blabla'
    end
  end

  it 'extract boolean property' do
    assert_nil Jars.to_boolean('JARS_SOMETHING')

    ENV['JARS_SOMETHING'] = 'falsy'
    _(Jars.to_boolean('JARS_SOMETHING')).must_equal false

    ENV[jars_verbose = 'JARS_VERBOSE'] = 'true'
    _(Jars.to_boolean(jars_verbose)).must_equal true
    _(Jars.verbose?).must_equal true
    _(jars_verbose).must_equal 'JARS_VERBOSE' # no mod

    if defined? JRUBY_VERSION
      jars_skip = 'JARS_SKIP'
      begin
        java.lang.System.set_property('jars.skip', 'true')
        java.lang.System.set_property('jars.quiet', 'false')
        java.lang.System.set_property('jars.debug', '')

        _(Jars.to_boolean(jars_skip)).must_equal true
        _(Jars.skip?).must_equal true
        _(jars_skip).must_equal 'JARS_SKIP' # no mod

        _(Jars.to_boolean('JARS_DEBUG')).must_equal true
        _(Jars.to_boolean('jars.quiet')).must_equal false
      ensure
        java.lang.System.clear_property('jars.skip')
        java.lang.System.clear_property('jars.quiet')
        java.lang.System.clear_property('jars.debug')
      end
    end
  end

  it 'treats debug as verbose' do
    ENV['JARS_DEBUG'] = 'true'
    ENV['JARS_VERBOSE'] = nil
    Jars.reset

    _(Jars.debug?).must_equal true
    _(Jars.verbose?).must_equal true
  end

  it 'does not treat explicit verbose false as quiet' do
    ENV['JARS_VERBOSE'] = 'false'
    ENV['JARS_QUIET'] = nil
    Jars.reset

    $stderr = StringIO.new
    Jars.warn('visible warning')

    _($stderr.string).must_equal "visible warning\n"
  ensure
    $stderr = STDERR
  end

  it 'lets debug override quiet warnings' do
    ENV['JARS_QUIET'] = 'true'
    ENV['JARS_DEBUG'] = 'true'
    Jars.reset

    $stderr = StringIO.new
    Jars.warn('debug warning')

    _($stderr.string).must_equal "debug warning\n"
  ensure
    $stderr = STDERR
  end

  it 'logs readable require_jar debug output' do
    ENV['JARS_HOME'] = File.join('specs', 'repo')
    ENV['JARS_DEBUG'] = 'true'
    Jars.reset

    begin
      $stderr = StringIO.new
      _(require_jar('org.slf4j', 'slf4j-simple', '1.6.6')).must_equal true
      _(require_jar('org.slf4j', 'slf4j-simple', '1.6.4')).must_equal false

      conflict = 'jar conflict: org.slf4j:slf4j-simple already loaded with version 1.6.6; ' \
                 'skipping requested version 1.6.4'
      _($stderr.string).must_include 'jar registration: ["org.slf4j", "slf4j-simple", "1.6.6"]; loaded=true'
      _($stderr.string).must_include conflict
      _($stderr.string).must_include "\n\tspecs/jars_spec.rb"
    ensure
      $stderr = STDERR
      ENV['JARS_HOME'] = nil
    end
  end

  it 'applies lock_down debug and verbose options while preserving environment' do
    require 'jars/lock_down'

    ENV['JARS_DEBUG'] = nil
    ENV['JARS_VERBOSE'] = nil
    ENV['JARS_SKIP_LOCK'] = 'false'
    Jars.reset

    fake = Object.new
    def fake.lock_down(_vendor_dir = nil, **_kwargs)
      [Jars.debug?, Jars.verbose?, ENV['JARS_SKIP_LOCK']]
    end

    result = Jars::LockDown.stub(:new, fake) do
      Jars.lock_down(debug: true, verbose: false)
    end

    _(result).must_equal [true, true, 'true']
    _(ENV['JARS_DEBUG']).must_be_nil
    _(ENV['JARS_VERBOSE']).must_be_nil
    _(ENV['JARS_SKIP_LOCK']).must_equal 'false'
  end

  it 'extract maven settings' do
    settings = Jars.maven_settings # likely nil on CI

    ENV['JARS_MAVEN_SETTINGS'] = 'specs/settings.xml'
    Jars.reset
    _(settings).wont_equal Jars.maven_settings
    _(Jars.maven_settings).must_equal File.expand_path('specs/settings.xml')

    ENV['JARS_MAVEN_SETTINGS'] = nil

    Jars.reset
    Dir.chdir(File.dirname(__FILE__)) do
      _(settings).wont_equal Jars.maven_settings
      _(Jars.maven_settings).must_equal File.expand_path('settings.xml')
    end
  end

  it 'determines JARS_HOME' do
    ENV['M2_HOME'] = ENV['MAVEN_HOME'] = '' # so that it won't interfere
    ENV['JARS_QUIET'] = 'true'
    ENV['JARS_MAVEN_SETTINGS'] = 'does-not-exist/settings.xml'
    home = Jars.home
    _(home).must_equal(File.join(ENV['HOME'], '.m2', 'repository'))

    ENV['JARS_LOCAL_MAVEN_REPO'] = nil
    ENV['JARS_MAVEN_SETTINGS'] = File.join('specs', 'settings.xml')
    Jars.reset
    _(Jars.home).wont_equal home
    _(Jars.home).must_equal 'specs'

    ENV['JARS_MAVEN_SETTINGS'] = nil
  end

  it "determines JARS_HOME (when no ENV['HOME'] present)" do
    ENV['M2_HOME'] = ENV['MAVEN_HOME'] = '' # so that it won't interfere
    env_home = ENV['HOME']
    ENV.delete('HOME')
    ENV['JARS_QUIET'] = true.to_s
    ENV['JARS_MAVEN_SETTINGS'] = 'does-not-exist/settings.xml'
    _(Jars.home).must_equal(File.join(env_home, '.m2', 'repository'))
  end

  it 'determines JARS_HOME (from global settings.xml)' do
    ENV['JARS_LOCAL_MAVEN_REPO'] = nil
    ENV['HOME'] = "/tmp/oul'bollocks!"
    ENV['M2_HOME'] = __dir__
    ENV_JAVA['repo.path'] = 'specs'
    _(Jars.home).must_equal('specs/repository')
    ENV['JARS_LOCAL_MAVEN_REPO'] = nil
  end

  it 'raises RuntimeError on requires of unknown group-id' do
    _ { require_jar('org.something', 'slf4j-simple', '1.6.6') }.must_raise RuntimeError
  end

  it 'does not require jar but sets version to unknown' do
    ENV['JARS_HOME'] = File.join('specs', 'repo')
    Jars.reset

    begin
      _(require_jar('org.slf4j', 'slf4j-simple') { nil }).must_equal true

      $stderr = StringIO.new
      _(require_jar('org.slf4j', 'slf4j-simple') { '1.6.6' }).must_equal false

      expected = 'jar conflict: org.slf4j:slf4j-simple already loaded with version unknown; ' \
                 "skipping requested version 1.6.6\n"
      _($stderr.string).must_equal expected
    ensure
      $stderr = STDERR
      ENV['JARS_HOME'] = nil
    end
  end

  it 'warn on version conflict' do
    ENV['JARS_HOME'] = File.join('specs', 'repo')
    Jars.reset

    begin
      _(require_jar('org.slf4j', 'slf4j-simple', '1.6.6')).must_equal true
      $stderr = StringIO.new
      _(require_jar('org.slf4j', 'slf4j-simple') { '1.6.6' }).must_equal false
      _($stderr.string).must_equal ''

      $stderr = StringIO.new
      _(require_jar('org.slf4j', 'slf4j-simple', '1.6.4')).must_equal false
      expected = 'jar conflict: org.slf4j:slf4j-simple already loaded with version 1.6.6; ' \
                 "skipping requested version 1.6.4\n"
      _($stderr.string).must_equal expected

      $stderr = StringIO.new
      _(require_jar('org.slf4j', 'slf4j-simple') { '1.6.4' }).must_equal false
      expected = 'jar conflict: org.slf4j:slf4j-simple already loaded with version 1.6.6; ' \
                 "skipping requested version 1.6.4\n"
      _($stderr.string).must_equal expected

      $stderr = StringIO.new
      _(require_jar('org.slf4j', 'slf4j-simple') { nil }).must_equal false
      expected = 'jar conflict: org.slf4j:slf4j-simple already loaded with version 1.6.6; ' \
                 "skipping requested version unknown\n"
      _($stderr.string).must_equal expected
    ensure
      $stderr = STDERR
      ENV['JARS_HOME'] = nil
    end
  end

  it 'finds jars on the load_path' do
    $LOAD_PATH << File.join('specs', 'load_path')
    ENV['JARS_HOME'] = 'something'
    Jars.reset

    begin
      $stderr = StringIO.new

      _ { require_jar('org.slf4j', 'slf4j-simple', '1.6.6') }.must_raise RuntimeError

      $stderr.flush

      $stderr = StringIO.new
      _(require_jar('org.slf4j', 'slf4j-simple', '1.6.4')).must_equal true

      _(require_jar('org.slf4j', 'slf4j-simple', '1.6.6')).must_equal false

      expected = 'jar conflict: org.slf4j:slf4j-simple already loaded with version 1.6.4; ' \
                 "skipping requested version 1.6.6\n"
      _($stderr.string).must_equal expected
    ensure
      $stderr = STDERR
      ENV['JARS_HOME'] = nil
    end
  end
  it 'freezes jar loading unless jar is not loaded yet' do
    size = $CLASSPATH.length

    Jars.freeze_loading

    require 'jopenssl/version'

    require_jar 'org.bouncycastle', 'bcpkix-jdk15on', JOpenSSL::BOUNCY_CASTLE_VERSION

    _($CLASSPATH.length).must_equal size

    $stderr = StringIO.new

    require_jar 'org.bouncycastle', 'bcpkix-jdk15on', '1.46'

    _($stderr.string).must_equal ''
  ensure
    $stderr = STDERR
  end

  it 'allows to programatically disable require_jar' do
    require 'jopenssl/version'

    size = $CLASSPATH.length

    Jars.require = false

    out = require_jar 'org.bouncycastle', 'bcpkix-jdk15on', JOpenSSL::BOUNCY_CASTLE_VERSION
    assert_nil out

    out = require_jar 'org.jruby', 'jruby-rack', '1.1.16'
    assert_nil out

    _($CLASSPATH.length).must_equal size
  end

  it 'does not warn on conflicts after turning into silent mode' do
    skip('$CLASSPATH is not clean - need to skip spec') if $CLASSPATH.detect { |a| a.include?('bcpkix-jdk18on') }

    size = $CLASSPATH.length

    Jars.no_more_warnings

    require 'jopenssl/version'

    if require_jar('org.bouncycastle', 'bcpkix-jdk18on', JOpenSSL::BOUNCY_CASTLE_VERSION)
      _($CLASSPATH.length).must_equal(size + 1)
    end

    $stderr = StringIO.new

    require_jar 'org.bouncycastle', 'bcpkix-jdk18on', '1.70'

    _($stderr.string).must_equal ''
  ensure
    $stderr = STDERR
  end

  it 'no warnings on reload' do
    $stderr = StringIO.new

    load File.expand_path('lib/jar_dependencies.rb')

    _($stderr.string).must_equal ''
  ensure
    $stderr = STDERR
  end

  it 'requires jars from various default places' do
    pwd = File.expand_path(__dir__)
    $LOAD_PATH << File.join(pwd, 'path')

    $stderr = StringIO.new
    Jars.require_jars_lock # make sure we locked with no lock file
    Dir.chdir(pwd) do
      require_jar 'more', 'sample', '4'
      require_jar 'more', 'sample', '2'
      require_jar 'more', 'sample', '3'
    end

    _($stderr.string).wont_match(/skipping requested version 1/)
    _($stderr.string).must_match(/skipping requested version 2/)
    _($stderr.string).must_match(/skipping requested version 3/)
    _($stderr.string).wont_match(/skipping requested version 4/)
  ensure
    $stderr = STDERR

    $LOAD_PATH.delete(File.join(pwd, 'path'))
  end

  it 'lock is Jars.lock by default' do
    _(Jars.lock).must_equal 'Jars.lock'
  end

  it 'lock gets set during setup' do
    Jars.setup jars_lock: 'Jars_no_jline.lock'
    _(Jars.lock).must_equal 'Jars_no_jline.lock'
  end
end
