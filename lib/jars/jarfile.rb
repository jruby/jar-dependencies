# frozen_string_literal: true

require 'jars/gemspec_artifacts'

module Jars
  # Self-contained reader for the (j)bundler Jarfile DSL.
  class Jarfile
    def self.load(file)
      new.tap { |jarfile| jarfile.eval_file(file) }
    end

    Repository = Struct.new(:name, :url, :snapshot)
    LocalJar = Struct.new(:group_id, :artifact_id, :version, :path) do
      # a system-scoped Jars.lock entry: "group:artifact:version:system:path"
      def to_lock_entry
        "#{group_id}:#{artifact_id}:#{version}:system:#{path}"
      end
    end

    def initialize
      @artifacts = []
      @repositories = []
      @local_jars = []
    end

    attr_reader :artifacts, :repositories, :local_jars

    def eval_file(file)
      instance_eval(File.read(file), file.to_s)
      self
    end

    # -- DSL --

    def jar(*args, &block)
      add(:jar, args, &block)
    end

    def pom(*args, &block)
      add(:pom, args, &block)
    end

    def scope(scope)
      previous = @scope
      @scope = scope
      yield if block_given?
    ensure
      @scope = previous
    end

    def repository(name, url = nil)
      @repositories << Repository.new(name.to_s, url || name, false)
    end
    alias_method :source, :repository

    def snapshot_repository(name, url = nil)
      @repositories << Repository.new(name.to_s, url || name, true)
    end

    # a local jar on disk - carried through as a system-scoped dependency
    def local(path)
      abs = File.expand_path(path)
      name = File.basename(abs).sub(/\.jar$/, '')
      if (dash = name.rindex('-'))
        version = name[(dash + 1)..]
        name = name[0...dash]
      else
        version = '0'
      end
      @local_jars << LocalJar.new('ruby.maven-tools.jar', name, version, abs)
    end

    # @deprecated in maven-tools, kept as a no-op so existing Jarfiles still load
    def jruby(*)
      nil
    end

    # Normalizes a DSL exclusion list ('group:artifact' or ['group', 'artifact']) to coordinate strings
    def self.normalize_exclusions(list)
      return [] if list.nil?

      list.map { |e| e.is_a?(Array) ? e.join(':') : e.to_s }
    end

    private

    def add(type, args, &block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      group_id, artifact_id, classifier, version = coordinate(args)

      config = DepConfig.new(options)
      config.instance_eval(&block) if block

      classifier ||= config.classifier
      scope = (config.scope || @scope)&.to_s
      exclusions = build_exclusions(config.exclusions)
      @artifacts << GemspecArtifacts::Artifact.new(
        type.to_s, group_id, artifact_id, classifier, version, exclusions, scope: scope
      )
    end

    # Normalizes the positional coordinate forms into [group, artifact, classifier, version].
    # Mirrors maven-tools Artifact.from: the colon-packed string carries the classifier.
    def coordinate(args)
      case args.size
      when 1
        # 'group:artifact:version' or 'group:artifact:version:classifier'
        group_id, artifact_id, version, classifier = args[0].split(':')
      when 2
        # 'group:artifact', 'version' or 'group:artifact:classifier', 'version'
        group_id, artifact_id, classifier = args[0].split(':')
        version = args[1]
      when 3
        if args[0].include?(':')
          # 'group:artifact[:classifier]', version-constraint, version-constraint
          group_id, artifact_id, classifier = args[0].split(':')
          version = args[1..].join(', ')
        else
          # 'group', 'artifact', 'version'
          group_id, artifact_id, version = args
        end
      end
      [group_id, artifact_id, classifier, version]
    end

    # @param coords [Array<String>] normalized 'group:artifact' exclusion coordinates
    def build_exclusions(coords)
      return nil if coords.nil? || coords.empty?

      GemspecArtifacts::Exclusions.new("[#{coords.join(', ')}]")
    end

    # Collects scope / classifier / exclusions declared in a jar/pom block, seeded by inline options.
    # scope / classifier / exclusions double as DSL setters (with a value) and readers (no value).
    class DepConfig
      def initialize(options)
        @scope = options[:scope]
        @classifier = options[:classifier]
        @exclusions = Jarfile.normalize_exclusions(options[:exclusions])
      end

      # dual getter (no arg, read after eval) / setter (DSL call with a value)
      def scope(value = nil)
        value.nil? ? @scope : (@scope = value)
      end

      def classifier(value = nil)
        value.nil? ? @classifier : (@classifier = value)
      end

      def exclusion(*args, &block)
        @exclusions << ExclusionBuilder.coordinate(*args, &block)
      end

      def exclusions(*list, &block)
        list.each { |e| @exclusions << ExclusionBuilder.coordinate(e) }
        instance_eval(&block) if block
        @exclusions
      end
    end

    # Resolves one exclusion declaration (any DSL form) to a 'group:artifact' coordinate.
    module ExclusionBuilder
      def self.coordinate(*args, &block)
        return from_block(args, &block) if block

        case args.first
        when Hash then "#{args.first[:group_id]}:#{args.first[:artifact_id]}"
        when Array then args.first.join(':')
        else args.join(':') # 'group:artifact', or 'group', 'artifact'
        end
      end

      def self.from_block(args, &block)
        receiver = Receiver.new
        receiver.group_id(args.first) if args.first.is_a?(String)
        receiver.instance_eval(&block)
        "#{receiver.group_id}:#{receiver.artifact_id}"
      end

      # Receiver for the `exclusion do group_id ..; artifact_id .. end` form
      class Receiver
        def group_id(value = nil)
          value.nil? ? @group_id : (@group_id = value)
        end

        def artifact_id(value = nil)
          value.nil? ? @artifact_id : (@artifact_id = value)
        end
      end
    end
  end
end
