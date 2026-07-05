# frozen_string_literal: true

require 'jar_dependencies'
require 'jars/maven_exec'

module Jars
  class Installer
    class Dependency
      attr_reader :path, :file, :gav, :scope, :type, :coord

      # @param line [String] Maven dependency:list output line
      # @return [Dependency, nil]
      def self.parse(line)
        return unless /:jar:|:pom:/.match?(line)

        # remove ANSI escape sequences and module section (https://issues.apache.org/jira/browse/MDEP-974)
        line = line.gsub(/\e\[\d*m/, '')
        line = line.gsub(/ -- module.*/, '')

        type = if line.index(':pom:')
                 :pom
               elsif line.index(':jar:')
                 :jar
               end

        line.strip!

        all_types = /:jar:|:pom:|:test:|:compile:|:runtime:|:provided:|:system:/
        coord = line.sub(/:[^:]+:([A-Z]:\\)?[^:]+$/, '')
        first, second = coord.split(/:#{type}:/)
        group_id, artifact_id = first.split(':')
        parts = group_id.split('.')
        parts << artifact_id
        parts << second.split(':')[-1]
        file = line.slice(coord.length, line.length).sub(all_types, '').strip
        last = file.reverse.index(%r{\\|/})
        parts << line[-last..]
        path = File.join(parts).strip

        scope = case line
                when /:provided:/
                  :provided
                when /:test:/
                  :test
                else
                  :runtime
                end

        new(
          path: path,
          file: file,
          gav: coord.sub(all_types, ':'),
          scope: scope,
          type: type,
          coord: coord,
          system: !line.index(':system:').nil?
        )
      end

      # @param dep [Jars::Mima::ResolvedDependency]
      # @return [Dependency]
      def self.from_resolved(dep)
        coord = "#{dep.group_id}:#{dep.artifact_id}:#{dep.type}:"
        coord << "#{dep.classifier}:" if dep.classifier
        coord << "#{dep.version}:#{dep.scope}"

        scope = case dep.scope
                when 'test'
                  :test
                when 'provided'
                  :provided
                else
                  :runtime
                end

        new(
          path: dep.path,
          file: dep.file,
          gav: dep.gav,
          scope: scope,
          type: dep.type.to_sym,
          coord: coord,
          system: dep.system?
        )
      end

      def initialize(path:, file:, gav:, scope:, type:, coord:, system: false)
        @path = path
        @file = file
        @gav = gav
        @scope = scope
        @type = type
        @coord = coord
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

    def self.load_from_resolved(resolved)
      resolved.each_with_object([]) do |mima_dep, result|
        next unless MavenExec::RESOLVED_TYPES.include?(mima_dep.type)

        dep = Dependency.from_resolved(mima_dep)
        result << dep if dep.scope == :runtime
      end
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
    def self.needs_to_write?(require_filename)
      require_filename && (!File.exist?(require_filename) || File.read(require_filename).match(COMMENT))
    end

    def self.write_require_jars(deps, require_filename)
      return unless needs_to_write?(require_filename)

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
      # first look if there are any requirements in the spec
      # and then if gem depends on jar-dependencies for runtime.
      # only then install the jars declared in the requirements
      spec = self.spec
      result = spec && !spec.requirements.empty? &&
               spec.dependencies.detect { |d| d.name == 'jar-dependencies' && d.type == :runtime }
      if result && spec.platform.to_s != 'java'
        Jars.warn "jar-dependencies found on non-java platform gem; skipping jar installation"
        false
      else
        result
      end
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
      puts "  jar dependencies for #{spec.spec_name} . . ." unless Jars.quiet?
      self.class.load_from_resolved(@mvn.resolve_dependencies)
    end
  end
end
