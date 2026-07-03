# frozen_string_literal: true

require 'jars/mima/version'
require 'jars/gemspec_artifacts'

module Jars
  # Resolver backed by the Mima Java library (MIni MAven).
  # Replaces the previous ruby-maven based resolution pipeline.
  #
  # Mima wraps the Maven Resolver (Aether) API as a standalone library (no Maven process is spawned).
  module Mima
    class << self
      @@jars_loaded = nil # rubocop:disable Style/ClassVars

      # Loads the bundled Mima jars onto the classpath.
      # Safe to call multiple times; only loads once.
      def ensure_jars_loaded
        return if @@jars_loaded

        configure_logging if Jars.debug?

        mima_dir = File.expand_path('mima', File.dirname(__FILE__))

        load File.join(mima_dir, "slf4j-api-#{SLF4J_VERSION}.jar")
        load File.join(mima_dir, "slf4j-simple-#{SLF4J_VERSION}.jar")
        load File.join(mima_dir, "jcl-over-slf4j-#{SLF4J_VERSION}.jar")
        load File.join(mima_dir, "context-#{MIMA_VERSION}.jar")
        load File.join(mima_dir, "standalone-static-uber-#{MIMA_VERSION}.jar")

        @@jars_loaded = true # rubocop:disable Style/ClassVars
      end

      # Builds a +ContextOverrides+ from jar-dependencies configuration
      # (local repo, user/global settings.xml).
      #
      # @return [Java::eu.maveniverse.maven.mima.context.ContextOverrides]
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

        builder.repositoryListener(aether_repository_listener)
        builder.transferListener(aether_transfer_listener)
        builder.build
      end

      # Creates a Mima Context. Caller is responsible for closing it.
      #
      # @param overrides [Java::eu.maveniverse.maven.mima.context.ContextOverrides, nil]
      #   optional overrides; when +nil+, {#context_overrides} is used
      # @return [Java::eu.maveniverse.maven.mima.context.Context]
      def create_context(overrides = nil)
        ensure_jars_loaded

        overrides ||= context_overrides
        runtime = Java::eu.maveniverse.maven.mima.context.Runtimes::INSTANCE.getRuntime
        runtime.create(overrides)
      end

      # Resolves transitive dependencies for the given artifacts.
      # Creates (and closes) its own Mima context.
      #
      # @param artifacts [Array<Jars::GemspecArtifacts::Artifact>] jar dependency declarations
      # @param all_dependencies [Boolean] when +true+, include provided/test scoped artifacts
      # @return [Array<ResolvedDependency>] resolved artifacts with local file paths
      def resolve_artifacts(artifacts, all_dependencies: false)
        context = create_context
        begin
          resolve_with_context(context, artifacts, all_dependencies: all_dependencies)
        ensure
          context.close
        end
      end

      # Resolves transitive dependencies using an existing Mima context.
      #
      # @param context [Java::eu.maveniverse.maven.mima.context.Context] an open Mima context
      # @param artifacts [Array<Jars::GemspecArtifacts::Artifact>] jar dependency declarations
      # @param all_dependencies [Boolean] when +true+, include provided/test scoped artifacts
      # @return [Array<ResolvedDependency>] resolved artifacts with local file paths
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
        collect_resolved(result.getRoot)
      end

      private

      def configure_logging
        return unless Object.const_defined?(:ENV_JAVA)

        set_default_java_property('org.slf4j.simpleLogger.defaultLogLevel', 'info')
        set_default_java_property('org.slf4j.simpleLogger.showThreadName', 'false')
        set_default_java_property('org.slf4j.simpleLogger.log.org.apache.maven', 'debug')
      end

      def set_default_java_property(key, value)
        ENV_JAVA[key] = value unless ENV_JAVA[key]
      end

      def aether_repository_listener
        org.eclipse.aether.RepositoryListener.impl do |method, event|
          case method
          when :artifactDescriptorInvalid
            Jars.debug { "[mima] invalid artifact descriptor #{artifact_label(event.getArtifact)}" }
          when :artifactDescriptorMissing
            Jars.debug { "[mima] missing artifact descriptor #{artifact_label(event.getArtifact)}" }
          when :metadataInvalid
            Jars.debug { "[mima] invalid metadata #{metadata_label(event.getMetadata)}" }
          when :artifactResolving
            Jars.debug { "[mima] resolving artifact #{artifact_label(event.getArtifact)}" }
          when :artifactResolved
            Jars.debug { resolved_message('artifact', event) }
          when :metadataResolving
            Jars.debug { "[mima] resolving metadata #{metadata_label(event.getMetadata)}" }
          when :metadataResolved
            Jars.debug { resolved_message('metadata', event) }
          when :artifactDownloading
            Jars.debug { download_message('artifact', event) }
          when :artifactDownloaded
            Jars.debug { downloaded_message('artifact', event) }
          when :metadataDownloading
            Jars.debug { download_message('metadata', event) }
          when :metadataDownloaded
            Jars.debug { downloaded_message('metadata', event) }
          end
        end
      end

      def aether_transfer_listener
        org.eclipse.aether.transfer.TransferListener.impl do |method, event|
          case method
          when :transferInitiated
            Jars.debug { transfer_message('initiated', event) }
          when :transferStarted
            Jars.debug { transfer_message('started', event) }
          when :transferCorrupted
            Jars.debug { transfer_message('corrupted', event) }
          when :transferSucceeded
            Jars.debug { transfer_message('succeeded', event, bytes: true) }
          when :transferFailed
            Jars.debug { transfer_message('failed', event) }
          end
        end
      end

      def resolved_message(kind, event)
        message = +"[mima] resolved #{kind} #{repository_item_label(event)}"
        message << " -> #{event.getFile.getAbsolutePath}" if event.getFile
        message << " (#{event.getException.message})" if event.getException
        message
      end

      def download_message(kind, event)
        message = +"[mima] downloading #{kind} #{repository_item_label(event)}"
        repository = event.getRepository
        message << " from #{repository}" if repository
        message
      end

      def downloaded_message(kind, event)
        message = +"[mima] downloaded #{kind} #{repository_item_label(event)}"
        message << " -> #{event.getFile.getAbsolutePath}" if event.getFile
        message << " (#{event.getException.message})" if event.getException
        message
      end

      def repository_item_label(event)
        artifact = event.getArtifact
        return artifact_label(artifact) if artifact

        metadata_label(event.getMetadata)
      end

      def artifact_label(artifact)
        artifact&.to_s || 'unknown'
      end

      def metadata_label(metadata)
        metadata&.to_s || 'unknown'
      end

      def transfer_message(action, event, bytes: false)
        resource = event.getResource
        location = "#{resource.getRepositoryUrl}#{resource.getResourceName}"
        message = +"[mima] transfer #{action} #{event.getRequestType.to_s.downcase} #{location}"
        message << " (#{format_bytes(event.getTransferredBytes)})" if bytes
        message << " (#{event.getException})" if event.getException
        message
      end

      def format_bytes(bytes)
        return "#{bytes} B" if bytes < 1024

        "#{(bytes / 1024.0).round(1)} KB"
      end

      # Converts {GemspecArtifacts::Artifact} objects to Aether +Dependency+ list,
      # filtering by scope unless +all_dependencies+ is set.
      #
      # @param artifacts [Array<Jars::GemspecArtifacts::Artifact>]
      # @param all_dependencies [Boolean]
      # @return [Array<org.eclipse.aether.graph.Dependency>]
      def artifacts_to_dependencies(artifacts, all_dependencies: false)
        filtered_artifacts = artifacts.select do |artifact|
          all_dependencies || (artifact.scope != 'provided' && artifact.scope != 'test')
        end

        filtered_artifacts.map do |artifact|
          aether_artifact = build_aether_artifact(artifact)
          scope = artifact.scope || 'compile'
          dep = org.eclipse.aether.graph.Dependency.new(aether_artifact, scope)

          if artifact.exclusions && !artifact.exclusions.empty?
            exclusions = artifact.exclusions.map do |ex|
              org.eclipse.aether.graph.Exclusion.new(ex.group_id, ex.artifact_id, '*', '*')
            end
            dep = dep.setExclusions(exclusions)
          end

          dep
        end
      end

      # Converts a single {GemspecArtifacts::Artifact} to an Aether +DefaultArtifact+.
      #
      # @param artifact [Jars::GemspecArtifacts::Artifact]
      # @return [org.eclipse.aether.artifact.DefaultArtifact]
      def build_aether_artifact(artifact)
        version = Jars::MavenVersion.resolve(artifact.version) || artifact.version
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

      # Walks the resolved dependency tree and collects {ResolvedDependency} objects.
      #
      # @param node [org.eclipse.aether.graph.DependencyNode] root of the resolved tree
      # @param result [Array<ResolvedDependency>] accumulator
      # @return [Array<ResolvedDependency>]
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

    # Structured result from dependency resolution.
    #
    # @!attribute [r] group_id
    #   @return [String] Maven group ID
    # @!attribute [r] artifact_id
    #   @return [String] Maven artifact ID
    # @!attribute [r] version
    #   @return [String] resolved version
    # @!attribute [r] classifier
    #   @return [String, nil] Maven classifier (e.g. +"sources"+, +"no_aop"+)
    # @!attribute [r] type
    #   @return [String] artifact type/extension (e.g. +"jar"+, +"pom"+)
    # @!attribute [r] scope
    #   @return [String] Maven scope (+"compile"+, +"runtime"+, +"test"+, +"provided"+, +"system"+)
    # @!attribute [r] file
    #   @return [String] absolute path to the resolved artifact in the local repository
    ResolvedDependency = Struct.new(:group_id, :artifact_id, :version, :classifier, :type, :scope, :file) do
      # @return [Boolean] true if scope is neither +test+ nor +provided+
      def runtime?
        scope != 'test' && scope != 'provided'
      end

      # @return [Boolean] true if scope is +system+
      def system?
        scope == 'system'
      end

      # Maven repository layout path relative to repo root.
      #
      # @return [String] e.g. +"org/slf4j/slf4j-api/1.7.36/slf4j-api-1.7.36.jar"+
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

      # Formats a line suitable for the +Jars.lock+ file.
      #
      # @return [String] e.g. +"org.slf4j:slf4j-api:1.7.36:compile:"+
      def to_lock_entry
        entry = +"#{group_id}:#{artifact_id}:"
        entry << "#{classifier}:" if classifier
        entry << "#{version}:#{scope}:"
        entry
      end

      # Colon-separated GAV string suitable for +require_jar+ calls.
      #
      # @return [String] e.g. +"org.slf4j:slf4j-api:1.7.36"+
      def gav
        parts = [group_id, artifact_id]
        parts << classifier if classifier
        parts << version
        parts.join(':')
      end

      # Relative jar path for vendoring / +require_jar+.
      #
      # @return [String] e.g. +"org/slf4j/slf4j-api/1.7.36/slf4j-api-1.7.36.jar"+
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
