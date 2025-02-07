# frozen_string_literal: true

require 'jar_dependencies'
require 'jars/maven_exec'

module Jars
  class Installer
    class Dependency
      attr_reader :path, :file, :gav, :scope, :type, :coord

      def self.new(line)
        super if /:jar:|:pom:/.match?(line)
      end

      def setup_type(line)
        if line.index(':pom:')
          @type = :pom
        elsif line.index(':jar:')
          @type = :jar
        end
      end
      private :setup_type

      def setup_scope(line)
        @scope =
          case line
          when /:provided:/
            :provided
          when /:test:/
            :test
          else
            :runtime
          end
      end
      private :setup_scope

      REG = /:jar:|:pom:|:test:|:compile:|:runtime:|:provided:|:system:/.freeze
      EMPTY = ''
      def initialize(line)
        # remove ANSI escape sequences and module section (https://issues.apache.org/jira/browse/MDEP-974)
        line = line.gsub(/\e\[\d*m/, '')
        line = line.gsub(/ -- module.*/, '')

        setup_type(line)

        line.strip!

        @coord = line.sub(/:[^:]+:([A-Z]:\\)?[^:]+$/, EMPTY)
        first, second = @coord.split(/:#{type}:/)
        group_id, artifact_id = first.split(':')
        parts = group_id.split('.')
        parts << artifact_id
        parts << second.split(':')[-1]
        @file = line.slice(@coord.length, line.length).sub(REG, EMPTY).strip
        last = @file.reverse.index(%r{\\|/})
        parts << line[-last..]
        @path = File.join(parts).strip

        setup_scope(line)

        @system = !line.index(':system:').nil?
        @gav = @coord.sub(REG, ':')
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
        dep = Dependency.new(line)
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
      @mvn.ruby_maven_install_options = options
    end

    def jars?
      # first look if there are any requirements in the spec
      # and then if gem depends on jar-dependencies for runtime.
      # only then install the jars declared in the requirements
      result = (spec = self.spec) && !spec.requirements.empty? &&
               spec.dependencies.detect { |d| d.name == 'jar-dependencies' && d.type == :runtime }
      if result && spec.platform.to_s != 'java'
        Jars.warn "\njar dependencies found on non-java platform gem - do not install jars\n"
        false
      else
        result
      end
    end

    private

    def do_install(vendor_dir, write_require_file)
      if !spec.require_paths.include?(vendor_dir) && vendor_dir
        raise "vendor dir #{vendor_dir} not in require_paths of gemspec #{spec.require_paths}"
      end

      target_dir = File.join(@mvn.basedir, vendor_dir || spec.require_path)
      jars_file = File.join(target_dir, "#{spec.name}_jars.rb")

      # write out new jars_file it write_require_file is true or
      # check timestamps:
      # do not generate file if specfile is older then the generated file
      if !write_require_file &&
         File.exist?(jars_file) &&
         File.mtime(@mvn.specfile) < File.mtime(jars_file)
        # leave jars_file as is
        jars_file = nil
      end
      deps = install_dependencies
      self.class.write_require_jars(deps, jars_file)
      self.class.vendor_jars(deps, target_dir) if vendor_dir
    end

    def install_dependencies
      deps = File.join(@mvn.basedir, 'deps.lst')

      puts "  jar dependencies for #{spec.spec_name} . . ." unless Jars.quiet?
      @mvn.resolve_dependencies_list(deps)

      self.class.load_from_maven(deps)
    ensure
      FileUtils.rm_f(deps) if deps
    end
  end
end
