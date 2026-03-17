# frozen_string_literal: true

require 'fileutils'
require 'jar_dependencies'
require 'jars/version'
require 'jars/maven_factory'
require 'jars/gemspec_artifacts'

module Jars
  class LockDown
    attr_reader :debug, :verbose

    def initialize(debug, verbose)
      @debug = debug
      @verbose = verbose
    end

    def maven_new
      factory = MavenFactory.new({}, @debug, @verbose)
      pom = File.expand_path('lock_down_pom.rb', __dir__)
      m = factory.maven_new(pom)
      m['jruby.plugins.version'] = Jars::JRUBY_PLUGINS_VERSION
      m['dependency.plugin.version'] = Jars::DEPENDENCY_PLUGIN_VERSION
      m['jars.basedir'] = File.expand_path(basedir)
      jarfile = File.expand_path(Jars.jarfile)
      m['jars.jarfile'] = jarfile if File.exist?(jarfile)
      attach_jar_coordinates_from_bundler_dependencies(m)
      m
    end
    private :maven_new

    def maven
      @maven ||= maven_new
    end

    def basedir
      File.expand_path('.')
    end

    def attach_jar_coordinates_from_bundler_dependencies(maven)
      load_path = $LOAD_PATH.dup
      require 'bundler'
      # TODO: make this group a commandline option
      Bundler.setup('default')
      maven.property('jars.bundler', true)
      cwd = File.expand_path('.')
      Gem.loaded_specs.each_value do |spec|
        # if gemspec is local then include all dependencies
        maven.attach_jars(spec, all_dependencies: cwd == spec.full_gem_path)
      end
    rescue LoadError => e
      if Jars.verbose?
        warn e.message
        warn 'no bundler found - ignore Gemfile if exists'
      end
    rescue Bundler::GemfileNotFound
    # do nothing then as we have bundler but no Gemfile
    rescue Bundler::GemNotFound
      warn "can not setup bundler with #{Bundler.default_lockfile}"
      raise
    ensure
      $LOAD_PATH.replace(load_path)
    end

    def lock_down(vendor_dir = nil, force: false, update: false, tree: nil)
      out = File.expand_path('.jars.output')
      tree_provided = tree
      tree ||= File.expand_path('.jars.tree')
      maven.property('jars.outputFile', out)
      maven.property('maven.repo.local', Jars.local_maven_repo)
      maven.property('jars.home', File.expand_path(vendor_dir)) if vendor_dir
      maven.property('jars.lock', File.expand_path(Jars.lock))
      maven.property('jars.force', force)
      maven.property('jars.update', update) if update
      # tell not to use Jars.lock as part of POM when running mvn
      maven.property('jars.skip.lock', true)

      args = ['gem:jars-lock']
      args += ['dependency:tree', '-P -gemfile.lock', "-DoutputFile=#{tree}"] if tree_provided

      puts
      puts '-- jar root dependencies --'
      puts
      status = maven.exec(*args)
      exit 1 unless status
      if File.exist?(tree)
        puts
        puts '-- jar dependency tree --'
        puts
        puts File.read(tree)
        puts
      end
      puts
      puts File.read(out).gsub("#{File.dirname(out)}/", '')
      puts
    ensure
      FileUtils.rm_f out
      FileUtils.rm_f tree
    end
  end
end
