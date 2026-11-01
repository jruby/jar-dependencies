# frozen_string_literal: true

require 'jar_dependencies'
require 'jars/version'
require 'jars/gemspec_artifacts'
require 'jars/jarfile'

module Jars
  class LockDown
    attr_reader :repositories, :local_jars

    def initialize
      @repositories = []
      @local_jars = []
    end

    def basedir
      File.expand_path('.')
    end

    private

    # @return [Array[Jars::GemspecArtifacts::Artifact]]
    def collect_artifacts
      collected = {} # artifact.key => artifact

      attach_jar_coordinates_from_bundler_dependencies(collected)

      # Also collect from local gemspec if present
      specs = Dir.children(basedir).sort.select { |f| f.end_with?('.gemspec') }
      if specs.size == 1
        spec_file = File.join(basedir, specs.first)
        spec = Gem::Specification.load(spec_file)
        raise "failed to load gemspec #{spec_file}" unless spec

        GemspecArtifacts.new(spec).artifacts.each { |a| collected[a.key] ||= a }
      end

      append_artifacts_from_jarfile_if_any(collected)

      collected.values
    end

    # jar/pom coordinates, repositories and local jars from a Jarfile (if any)
    def append_artifacts_from_jarfile_if_any(collected)
      file_path = File.expand_path(Jars.jarfile, basedir)
      return unless File.exist?(file_path)

      Jars.debug { "Jarfile loading from #{file_path}" }
      jarfile = Jars::Jarfile.load(file_path)
      @repositories.concat(jarfile.repositories)
      @local_jars.concat(jarfile.local_jars)

      jarfile.artifacts.each do |a|
        previous = collected[a.key]
        Jars.info { "Jarfile overrides #{previous.to_gacv} with #{a.to_gacv}" } if previous
        collected[a.key] = a # Jarfile entry overrides the same coordinate from a gemspec
      end
    end

    def attach_jar_coordinates_from_bundler_dependencies(collected)
      load_path = $LOAD_PATH.dup
      require 'bundler'
      # TODO: make this group a commandline option
      Bundler.setup('default')
      cwd = File.expand_path('.')
      Gem.loaded_specs.each_value do |spec|
        all = cwd == spec.full_gem_path # if gemspec is local then include all dependencies
        GemspecArtifacts.new(spec).artifacts.each do |a|
          next if collected.key?(a.key)
          next unless all || (a.scope != 'provided' && a.scope != 'test')

          collected[a.key] = a
        end
      end
    rescue LoadError => e
      Jars.warn "bundler unavailable (#{e.message}); skipping dependency discovery" if Jars.verbose?
    rescue Bundler::GemfileNotFound
      # bundler is available, but there is no Gemfile to inspect
    rescue Bundler::GemNotFound
      Jars.warn "cannot set up bundler with #{Bundler.default_lockfile}"
      raise
    ensure
      $LOAD_PATH.replace(load_path)
    end

    public

    def lock_down(vendor_dir = nil, force: false, update: false, tree: nil) # rubocop:disable Lint/UnusedMethodArgument
      lock_file = File.expand_path(Jars.lock)

      if !force && File.exist?(lock_file)
        puts 'Jars.lock already exists, use --force to overwrite'
        return
      end

      artifacts = collect_artifacts

      if artifacts.empty? && @local_jars.empty?
        puts 'no jar dependencies found'
        return
      end

      puts
      puts '-- jar root dependencies --'
      puts
      artifacts.each do |a|
        puts "      #{a.to_gacv}:#{a.scope || 'compile'}"
        puts "          exclusions: #{a.exclusions}" if a.exclusions && !a.exclusions.empty?
      end

      resolved = []
      unless artifacts.empty?
        context = Jars::Mima.create_context(repositories: @repositories)
        begin
          resolved = Jars::Mima.resolve_with_context(context, artifacts, all_dependencies: true)
        ensure
          context.close
        end
      end

      # Write Jars.lock
      File.open(lock_file, 'w') do |f|
        resolved.each do |dep|
          next unless dep.type == 'jar'

          f.puts dep.to_lock_entry
        end
        @local_jars.each { |local| f.puts local.to_lock_entry }
      end

      # Optionally vendor jars
      if vendor_dir
        require 'fileutils'
        vendor_path = File.expand_path(vendor_dir)
        resolved.each do |dep|
          next unless dep.type == 'jar' && dep.runtime? && !dep.system?

          target = File.join(vendor_path, dep.jar_path)
          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.cp(dep.file, target)
        end
      end

      if tree
        puts
        puts '-- jar dependency tree --'
        puts
        resolved.each do |dep|
          prefix = dep.classifier ? "#{dep.classifier}:" : ''
          puts "   #{dep.group_id}:#{dep.artifact_id}:#{prefix}#{dep.version}:#{dep.scope}"
        end
        puts
      end

      puts
      puts File.read(lock_file)
      puts
    end
  end
end
