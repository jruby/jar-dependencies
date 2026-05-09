# frozen_string_literal: true

require 'jar_dependencies'
require 'jars/gemspec_artifacts'

module Jars
  class MavenExec
    def find_spec(allow_no_file)
      specs = Dir['*.gemspec']
      case specs.size
      when 0
        raise 'no gemspec found' unless allow_no_file
      when 1
        specs.first
      else
        raise 'more than one gemspec found; please specify a specfile' unless allow_no_file
      end
    end
    private :find_spec

    attr_reader :basedir, :spec, :specfile

    def initialize(spec = nil)
      setup(spec)
    rescue StandardError, LoadError => e
      Jars.warn "unable to load gemspec (#{e.message}); skipping jar dependency discovery"
      Jars.debug(e)
    end

    def setup(spec = nil, allow_no_file: false)
      spec ||= find_spec(allow_no_file)

      case spec
      when String
        @specfile = File.expand_path(spec)
        @basedir = File.dirname(@specfile)
        Dir.chdir(@basedir) do
          spec = eval(File.read(@specfile), TOPLEVEL_BINDING, @specfile) # rubocop:disable Security/Eval
        end
      when Gem::Specification
        if File.exist?(spec.loaded_from)
          @basedir = spec.gem_dir
          @specfile = spec.loaded_from
        else
          # this happens with bundle and local gems
          # there spec_file is "not installed" but is inside the gem_dir directory
          Dir.chdir(spec.gem_dir) do
            setup(nil, allow_no_file: true)
          end
        end
      when nil
        # ignore
      else
        Jars.debug "unsupported spec argument #{spec.class}; expected String or Gem::Specification"
      end
      @spec = spec
    end

    def resolve_dependencies_list(file)
      require 'jars/mima'

      artifacts = GemspecArtifacts.new(@spec)
      is_local_file = File.expand_path(File.dirname(@specfile)) == File.expand_path(Dir.pwd)

      resolved = Jars::Mima.resolve_artifacts(artifacts.artifacts, all_dependencies: is_local_file)

      # Write output in Maven dependency:list format for Installer::Dependency compatibility
      allowed_types = %w[jar pom].freeze
      File.open(file, 'w') do |f|
        f.puts
        f.puts 'The following files have been resolved:'
        resolved.each do |dep|
          next unless allowed_types.include?(dep.type)

          line = +"   #{dep.group_id}:#{dep.artifact_id}:#{dep.type}:"
          line << "#{dep.classifier}:" if dep.classifier
          line << "#{dep.version}:#{dep.scope}:#{dep.file}"
          f.puts line
        end
      end
    end
  end
end
