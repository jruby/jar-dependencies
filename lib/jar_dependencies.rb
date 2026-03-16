# frozen_string_literal: true

#
# Copyright (C) 2014 Christian Meier
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

module Jars
  unless defined? Jars::SKIP_LOCK
    MAVEN_SETTINGS = 'JARS_MAVEN_SETTINGS'
    LOCAL_MAVEN_REPO = 'JARS_LOCAL_MAVEN_REPO'
    # lock file to use
    LOCK = 'JARS_LOCK'
    # where the locally stored jars are search for or stored
    HOME = 'JARS_HOME'
    # skip the gem post install hook
    SKIP = 'JARS_SKIP'
    # skip Jars.lock mainly to run lock_jars
    SKIP_LOCK = 'JARS_SKIP_LOCK'
    # do not require any jars if set to false
    REQUIRE = 'JARS_REQUIRE'
    # @private
    NO_REQUIRE = 'JARS_NO_REQUIRE'
    # no more warnings on conflict. this still requires jars but will
    # not warn. it is needed to load jars from (default) gems which
    # do contribute to any dependency manager (maven, gradle, jbundler)
    QUIET = 'JARS_QUIET'
    # show maven output
    VERBOSE = 'JARS_VERBOSE'
    # maven debug
    DEBUG = 'JARS_DEBUG'
    # vendor jars inside gem when installing gem
    VENDOR = 'JARS_VENDOR'
    # string used when the version is unknown
    UNKNOWN = 'unknown'
  end

  autoload :MavenSettings, 'jars/maven_settings'
  autoload :Classpath, 'jars/classpath'

  @jars_lock = false
  @jars = {}

  class << self
    def lock_down(debug: false, verbose: false, **kwargs)
      ENV[SKIP_LOCK] = 'true'
      require 'jars/lock_down' # do this lazy to keep things clean
      Jars::LockDown.new(debug, verbose).lock_down(kwargs.delete(:vendor_dir), **kwargs)
    ensure
      ENV[SKIP_LOCK] = nil
    end

    if defined? JRUBY_VERSION
      def to_prop(key)
        key = key.tr('_', '.')
        ENV_JAVA[(key.downcase!
                  key)] ||
          ENV[(key.tr!('.', '_')
               key.upcase!
               key)]
      end
    else
      def to_prop(key)
        ENV[key.tr('.', '_').upcase]
      end
    end

    def to_boolean(key)
      return nil if (prop = to_prop(key)).nil?

      prop.empty? || prop.eql?('true')
    end

    def skip?
      to_boolean(SKIP)
    end

    def require?
      if @require.nil?
        if (require = to_boolean(REQUIRE)).nil?
          no_require = to_boolean(NO_REQUIRE)
          @require = no_require.nil? || !no_require
        else
          @require = require
        end
      end
      @require
    end
    attr_writer :require

    def quiet?
      @quiet = to_boolean(QUIET) if @quiet.nil?
      @quiet
    end

    def no_more_warnings
      @quiet = true
    end

    def jarfile
      ENV['JARFILE'] || ENV_JAVA['jarfile'] || ENV['JBUNDLER_JARFILE'] || ENV_JAVA['jbundler.jarfile'] || 'Jarfile'
    end

    def verbose?
      to_boolean(VERBOSE)
    end

    def debug?
      to_boolean(DEBUG)
    end

    def vendor?
      to_boolean(VENDOR)
    end

    def freeze_loading
      self.require = false
    end

    def skip_lock?
      to_prop(SKIP_LOCK) || false
    end

    def lock
      @lock ||= to_prop(LOCK) || 'Jars.lock'
    end

    def jars_lock_from_class_loader
      return unless defined?(JRUBY_VERSION)

      if JRuby::Util.respond_to?(:class_loader_resources)
        JRuby::Util.class_loader_resources('Jars.lock')
      else
        require 'jruby'
        JRuby.runtime.jruby_class_loader.get_resources('Jars.lock').collect(&:to_s)
      end
    end

    def lock_path(basedir = nil)
      return lock if File.exist?(lock)

      basedir ||= '.'
      ['.', 'jars', 'vendor/jars'].each do |dir|
        file = File.join(basedir, dir, lock)
        return file if File.exist?(file)
      end
      nil
    end

    def reset
      instance_variables.each do |var|
        next if var == :@jars_lock

        instance_variable_set(var, nil)
      end
      Jars::MavenSettings.reset
      @jars = {}
    end

    def maven_local_settings
      Jars::MavenSettings.local_settings
    end

    def maven_user_settings
      Jars::MavenSettings.user_settings
    end

    def maven_settings
      Jars::MavenSettings.settings
    end

    def maven_global_settings
      Jars::MavenSettings.global_settings
    end

    def local_maven_repo
      @local_maven_repo ||= absolute(to_prop(LOCAL_MAVEN_REPO)) ||
                            detect_local_repository(maven_local_settings) ||
                            detect_local_repository(maven_user_settings) ||
                            detect_local_repository(maven_global_settings) ||
                            File.join(user_home, '.m2', 'repository')
    end

    def home
      @home ||= absolute(to_prop(HOME)) || local_maven_repo
    end

    def require_jars_lock!(scope = :runtime)
      urls = jars_lock_from_class_loader if to_prop(LOCK).nil?
      if urls && !urls.empty?
        @jars_lock = true

        done = []
        while done != urls
          urls.each do |url|
            next if done.member?(url)

            Jars.debug { "--- load jars from uri #{url}" }
            classpath = Jars::Classpath.new(nil, "uri:#{url}")
            classpath.require(scope)
            done << url
          end
        end
        no_more_warnings
      elsif (jars_lock = Jars.lock_path)
        Jars.debug { "--- load jars from #{jars_lock}" }
        @jars_lock = jars_lock

        classpath = Jars::Classpath.new(nil, jars_lock)
        classpath.require(scope)
        no_more_warnings
      end
      Jars.debug do
        loaded = @jars.collect { |k, v| "#{k}:#{v}" }
        "--- loaded jars ---\n\t#{loaded.join("\n\t")}"
      end
    end

    def setup(options = nil)
      case options
      when Symbol
        require_jars_lock!(options)
      when Hash
        @home = options[:jars_home]
        @lock = options[:jars_lock]
        require_jars_lock!(options[:scope] || :runtime)
      else
        require_jars_lock!
      end
    end

    def require_jars_lock
      return if @jars_lock

      require_jars_lock!
      @jars_lock ||= true # rubocop:disable Naming/MemoizedInstanceVariableName
    end

    def mark_as_required(group_id, artifact_id, *classifier_version)
      require_jar_with_block(group_id, artifact_id, *classifier_version) do
        # ignore
      end
    end

    def require_jar(group_id, artifact_id, *classifier_version)
      require_jars_lock unless skip_lock?
      if classifier_version.empty? && block_given?
        classifier_version = [yield].compact
        return mark_as_required(group_id, artifact_id, UNKNOWN) || false if classifier_version.empty?
      end
      require_jar_with_block(group_id, artifact_id, *classifier_version) do |gid, aid, version, classifier|
        do_require(gid, aid, version, classifier)
      end
    end

    def warn(msg = nil)
      return if (verbose? == nil && quiet?) || (verbose? == false && !debug?)

      Kernel.warn(msg || yield)
    end

    def debug(msg = nil)
      return unless debug?

      msg = "#{msg.inspect}\n\t#{(msg.backtrace || []).join("\n\t")}" if msg.is_a?(Exception)
      Kernel.warn(msg || yield)
    end

    def absolute(file)
      File.expand_path(file) if file
    end

    def user_home
      ENV['HOME'] || begin
        user_home = Dir.home if Dir.respond_to?(:home)
        user_home = ENV_JAVA['user.home'] if !user_home && Object.const_defined?(:ENV_JAVA)
        user_home
      end
    end

    private

    def require_jar_with_block(group_id, artifact_id, *classifier_version)
      version = classifier_version[-1]
      classifier = classifier_version[-2]

      coordinate = +"#{group_id}:#{artifact_id}"
      coordinate << ":#{classifier}" if classifier
      if @jars.key? coordinate
        if @jars[coordinate] == version
          false
        else
          @jars[coordinate] # version of already registered jar
        end
      else
        yield group_id, artifact_id, version, classifier
        @jars[coordinate] = version
        true
      end
    end

    def detect_local_repository(settings)
      return nil unless settings

      doc = File.read(settings)
      # TODO: filter out xml comments
      local_repo = doc.sub(%r{</localRepository>.*}m, '').sub(/.*<localRepository>/m, '')
      # replace maven like system properties embedded into the string
      local_repo.gsub!(/\$\{[a-zA-Z.]+\}/) do |a|
        ENV_JAVA[a[2..-2]] || a
      end
      local_repo = nil if local_repo.empty? || !File.exist?(local_repo)
      local_repo
    rescue => e
      Jars.debug(e)
      Jars.warn "error reading or parsing local settings from: #{settings}"
      nil
    end

    def to_jar(group_id, artifact_id, version, classifier = nil)
      file = +"#{group_id.tr('.', '/')}/#{artifact_id}/#{version}/#{artifact_id}-#{version}"
      file << "-#{classifier}" if classifier
      file << '.jar'
      file
    end

    def do_require(*args)
      jar = to_jar(*args)
      # use jar from PWD/vendor/jars if exists
      if File.exist?(vendor = File.join(Dir.pwd, 'vendor', 'jars', jar))
        require vendor
      # use jar from PWD/jars if exists
      elsif File.exist?(local = File.join(Dir.pwd, 'jars', jar))
        require local
      # use jar from local repository if exists
      elsif File.exist?(file = File.join(home, jar))
        require file
      else
        # otherwise try to find it on the load path
        require jar
      end
    rescue LoadError => e
      raise "\n\n\tyou might need to reinstall the gem which depends on the " \
            'missing jar or in case there is Jars.lock then resolve the jars with ' \
            "`lock_jars` command\n\n#{e.message} (LoadError)"
    end
  end
end

def require_jar(*args, &block)
  return nil unless Jars.require?

  result = Jars.require_jar(*args, &block)
  if result.is_a? String
    args << (yield || Jars::UNKNOWN) if args.size == 2 && block
    Jars.warn do
      "--- jar coordinate #{args[0..-2].join(':')} already loaded with version #{result} - omit version #{args[-1]}"
    end
    Jars.debug { "    try to load from #{caller.join("\n\t")}" }
    return false
  end
  Jars.debug { "    register #{args.inspect} - #{result == true}" }
  result
end
