# frozen_string_literal: true

require 'jars/gemspec_artifacts'

module Jars
  # Resolver backed by the Mima Java library (MIni MAven).
  # Replaces the previous ruby-maven based resolution pipeline.
  #
  # Mima wraps the Maven Resolver (Aether) API as a standalone library (no Maven process is spawned).
  module Mima
    MIMA_VERSION = '2.4.42'
    SLF4J_VERSION = '1.7.36'

    class << self
      @@jars_loaded = nil
      def ensure_jars_loaded
        return if @@jars_loaded

        mima_dir = File.expand_path('mima', File.dirname(__FILE__)).freeze
        load File.join(mima_dir, "standalone-static-uber-#{MIMA_VERSION}.jar")
        load File.join(mima_dir, "slf4j-api-#{SLF4J_VERSION}.jar")
        load File.join(mima_dir, "jcl-over-slf4j-#{SLF4J_VERSION}.jar")
        load File.join(mima_dir, "slf4j-simple-#{SLF4J_VERSION}.jar")

        @@jars_loaded = true
      end

      # Build a ContextOverrides from jar-dependencies configuration.
      def context_overrides
        ensure_jars_loaded

        builder = Java::eu.maveniverse.maven.mima.context.ContextOverrides.create
        builder.withUserSettings(true)

        # Local repository override
        local_repo = ::Jars.local_maven_repo
        builder.withLocalRepositoryOverride(java.nio.file.Paths.get(local_repo)) if local_repo

        # User settings.xml override
        settings = ::Jars::MavenSettings.settings
        builder.withUserSettingsXmlOverride(java.nio.file.Paths.get(settings)) if settings

        # Global settings.xml override
        global = ::Jars::MavenSettings.global_settings
        builder.withGlobalSettingsXmlOverride(java.nio.file.Paths.get(global)) if global

        builder.build
      end

      # Create a Mima Context. Caller must close it.
      def create_context(overrides = nil)
        ensure_jars_loaded

        overrides ||= context_overrides
        runtime = Java::eu.maveniverse.maven.mima.context.Runtimes::INSTANCE.getRuntime
        runtime.create(overrides)
      end

      # Resolve dependencies for a list of GemspecArtifacts::Artifact objects.
      #
      # Returns an Array of ResolvedDependency structs, each with:
      #   group_id, artifact_id, version, classifier, type, scope, file
      #
      # Options:
      #   all_dependencies: include provided/test scoped artifacts (default: false)
      def resolve_artifacts(artifacts, all_dependencies: false)
        context = create_context
        begin
          resolve_with_context(context, artifacts, all_dependencies: all_dependencies)
        ensure
          context.close
        end
      end

      # Lower-level: resolve with an existing context.
      def resolve_with_context(context, artifacts, all_dependencies: false)
        deps = artifacts_to_dependencies(artifacts, all_dependencies: all_dependencies)
        return [] if deps.empty?

        collect_request = org.eclipse.aether.collection.CollectRequest.new
        deps.each { |d| collect_request.addDependency(d) }
        collect_request.setRepositories(context.remoteRepositories)

        dependency_request = org.eclipse.aether.resolution.DependencyRequest.new
        dependency_request.setCollectRequest(collect_request)

        result = context.repositorySystem.resolveDependencies(
          context.repositorySystemSession, dependency_request
        )

        root = result.getRoot
        collect_resolved(root)
      end

      private

      # Convert GemspecArtifacts::Artifact array to Aether Dependency list.
      def artifacts_to_dependencies(artifacts, all_dependencies: false)
        filtered = artifacts.select do |a|
          all_dependencies || (a.scope != 'provided' && a.scope != 'test')
        end

        filtered.map do |a|
          aether_artifact = build_aether_artifact(a)
          scope = a.scope || 'compile'
          dep = org.eclipse.aether.graph.Dependency.new(aether_artifact, scope)

          if a.exclusions && !a.exclusions.empty?
            exclusions = a.exclusions.map do |ex|
              org.eclipse.aether.graph.Exclusion.new(ex.group_id, ex.artifact_id, '*', '*')
            end
            dep = dep.setExclusions(exclusions)
          end

          dep
        end
      end

      def build_aether_artifact(artifact)
        version = Jars::MavenVersion.new(artifact.version) || artifact.version
        if artifact.classifier
          org.eclipse.aether.artifact.DefaultArtifact.new(
            artifact.group_id, artifact.artifact_id, artifact.classifier,
            artifact.type || 'jar', version
          )
        else
          org.eclipse.aether.artifact.DefaultArtifact.new(
            artifact.group_id, artifact.artifact_id,
            artifact.type || 'jar', version
          )
        end
      end

      # Walk the resolved dependency tree and collect ResolvedDependency objects.
      def collect_resolved(node, result = [])
        node.getChildren.each do |child|
          dep = child.getDependency
          next unless dep

          artifact = dep.getArtifact
          next unless artifact.getFile # skip unresolved

          result << ResolvedDependency.new(
            artifact.getGroupId,
            artifact.getArtifactId,
            artifact.getVersion,
            artifact.getClassifier.to_s.empty? ? nil : artifact.getClassifier,
            artifact.getExtension,
            dep.getScope,
            artifact.getFile.getAbsolutePath
          )

          collect_resolved(child, result)
        end
        result
      end
    end

    # Structured result from resolution.
    ResolvedDependency = Struct.new(:group_id, :artifact_id, :version, :classifier, :type, :scope, :file) do
      def runtime?
        scope != 'test' && scope != 'provided'
      end

      def system?
        scope == 'system'
      end

      # Maven repository layout path relative to repo root.
      def path
        parts = group_id.split('.')
        parts << artifact_id
        parts << version
        filename = +"#{artifact_id}-#{version}"
        filename << "-#{classifier}" if classifier
        filename << ".#{type || 'jar'}"
        parts << filename
        File.join(parts)
      end

      # GAV string suitable for Jars.lock format.
      def to_lock_entry
        entry = +"#{group_id}:#{artifact_id}:"
        entry << "#{classifier}:" if classifier
        entry << "#{version}:#{scope}:"
        entry
      end

      # GAV string using : separator, suitable for require_jar calls.
      def gav
        parts = [group_id, artifact_id]
        parts << classifier if classifier
        parts << version
        parts.join(':')
      end

      # Relative jar path for vendoring / require_jar.
      def jar_path
        parts = group_id.split('.')
        parts << artifact_id
        parts << version
        filename = +"#{artifact_id}-#{version}"
        filename << "-#{classifier}" if classifier
        filename << '.jar'
        parts << filename
        File.join(parts)
      end
    end
  end
end
