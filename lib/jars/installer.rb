# frozen_string_literal: true

require 'jar_dependencies'
require 'jars/maven_exec'

module Jars
  class Installer
    class Dependency
      EMPTY = ""
      # the trailing ":<file>" of a dependency line; the file may itself contain
      # a ':' on Windows (C:\...), hence the optional drive-letter prefix
      TRAILING_FILE = /:(?<file>(?:[A-Z]:\\)?[^:]+)\z/.freeze

      # A dependency:list line has the form
      #   groupId:artifactId:type[:classifier]:version:scope:/path/to/file
      def self.parse(line)
        return unless /:jar:|:pom:/.match?(line)

        line = line.dup
        # remove ANSI escape sequences and module section (https://issues.apache.org/jira/browse/MDEP-974)
        line.gsub!(/\e\[\d*m/, EMPTY)
        line.gsub!(/ -- module.*/, EMPTY)
        line.strip!

        # Peel off the trailing file path first: since it may contain a ':' it
        # cannot take part in the split below. What is left (pre_match) is
        # colon-clean, so every field is addressed by position -- never by
        # matching a keyword, which breaks when an artifact id is itself a scope
        # or type keyword (e.g. "com.dylibso.chicory:runtime:jar:1.7.5").
        tail = line.match(TRAILING_FILE)
        file = tail[:file]

        # classifier is the only optional field, so there are exactly 5 or 6
        components = tail.pre_match.split(':')
        if components.size == 6
          group_id, artifact_id, type, classifier, version, scope_name = components
        else
          group_id, artifact_id, type, version, scope_name = components
        end

        coord = [group_id, artifact_id, type, classifier, version].compact.join(':')
        gav = [group_id, artifact_id, classifier, version].compact.join(':')
        path = File.join(*group_id.split('.'), artifact_id, version, file[%r{[^\\/]+\z}])

        scope =
          case scope_name
          when 'provided'
            :provided
          when 'test'
            :test
          else
            :runtime
          end

        new(type.to_sym, scope, coord, gav, file, path, scope_name == 'system')
      end

      attr_reader :path, :file, :gav, :scope, :type, :coord

      def initialize(type, scope, coord, gav, file, path, system)
        @type = type
        @scope = scope
        @coord = coord
        @gav = gav
        @file = file
        @path = path
        @system = system
      end

      def system?
        @system
      end
    end

    def self.install_jars(write_require_file: false)
      new.install_jars(write_require_file: write_require_file)
    end

    def self.load_from_maven(file)
      result = []
      File.read(file).each_line do |line|
        dep = Dependency.parse(line)
        result << dep if dep && dep.scope == :runtime
      end
      result
    end

    def self.vendor_file(dir, dep)
      return unless !dep.system? && dep.type == :jar && dep.scope == :runtime

      vendored = File.join(dir, dep.path)
      FileUtils.mkdir_p(File.dirname(vendored))
      FileUtils.cp(dep.file, vendored)
    end

    def self.print_require_jar(file, dep, fallback: false)
      return if dep.type != :jar || dep.scope != :runtime

      if dep.system?
        file&.puts("require '#{dep.file}'")
      elsif dep.scope == :runtime
        if fallback
          file&.puts("  require '#{dep.path}'")
        else
          file&.puts("  require_jar '#{dep.gav.gsub(':', "', '")}'")
        end
      end
    end

    COMMENT = '# this is a generated file, to avoid over-writing it just delete this comment'

    def self.write_require_jars(deps, require_filename)
      return if !require_filename || (
        File.exist?(require_filename) && !File.read(require_filename).index(COMMENT)
      )

      FileUtils.mkdir_p(File.dirname(require_filename))
      File.open(require_filename, 'w') do |f|
        f.puts COMMENT
        f.puts 'begin'
        f.puts "  require 'jar_dependencies'"
        f.puts 'rescue LoadError'
        deps.each do |dep|
          # do not use require_jar method
          print_require_jar(f, dep, fallback: true)
        end
        f.puts 'end'
        f.puts
        f.puts 'if defined? Jars'
        deps.each do |dep|
          print_require_jar(f, dep)
        end
        f.puts 'end'
      end
    end

    def self.vendor_jars(deps, dir)
      deps.each do |dep|
        vendor_file(dir, dep)
      end
    end

    def initialize(spec = nil)
      @mvn = MavenExec.new(spec)
    end

    def spec
      @mvn.spec
    end

    def vendor_jars(vendor_dir = nil, write_require_file: true)
      return unless jars?

      if Jars.to_prop(Jars::VENDOR) == 'false'
        vendor_dir = nil
      else
        vendor_dir ||= spec.require_path
      end
      do_install(vendor_dir, write_require_file)
    end

    def self.vendor_jars!(vendor_dir = nil)
      new.vendor_jars!(vendor_dir)
    end

    def vendor_jars!(vendor_dir = nil, write_require_file: true)
      vendor_dir ||= spec.require_path
      do_install(vendor_dir, write_require_file)
    end

    def install_jars(write_require_file: true)
      return unless jars?

      do_install(nil, write_require_file)
    end

    def ruby_maven_install_options=(options)
      # no-op: kept for backward compatibility with post_install_hook
    end

    def jars?
      spec = self.spec
      return if spec.nil? # rubocop:disable Style/ReturnNilInPredicateMethodDefinition
      return false unless spec.requirements&.any?
      return false unless spec.runtime_dependencies.find { |s| s.name == 'jar-dependencies' }

      return true if spec.platform.to_s == 'java'

      Jars.warn "jar-dependencies found on non-java platform gem; skipping jar installation"
      nil # rubocop:disable Style/ReturnNilInPredicateMethodDefinition
    end

    private

    def do_install(vendor_dir, write_require_file)
      require_paths = spec.require_paths
      if vendor_dir && !require_paths.include?(vendor_dir)
        raise "vendor dir #{vendor_dir} not in require_paths of gemspec #{require_paths}"
      end

      target_dir = File.join(@mvn.basedir, vendor_dir || spec.require_path)
      jars_file = File.join(target_dir, "#{spec.name}_jars.rb")

      # write out new jars_file if write_require_file is true or check timestamps:
      # do not generate file if specfile is older than the generated file
      if !write_require_file && File.exist?(jars_file) && File.mtime(@mvn.specfile) < File.mtime(jars_file)
        jars_file = nil # leave jars_file as is
      end
      deps = install_dependencies
      self.class.write_require_jars(deps, jars_file)
      self.class.vendor_jars(deps, target_dir) if vendor_dir
    end

    def install_dependencies
      deps = File.join(@mvn.basedir, 'deps.lst')

      Jars.info("jar dependencies for #{spec.spec_name} ", newline: false)
      @mvn.resolve_dependencies_list(deps)
      Jars.info("") # newline after progress dots

      self.class.load_from_maven(deps)
    ensure
      FileUtils.rm_f(deps) if deps
    end
  end
end
