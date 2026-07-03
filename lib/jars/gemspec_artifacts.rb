# frozen_string_literal: true

module Jars
  module MavenVersion
    class << self
      def resolve(*args)
        return nil if args.empty? || (args.size == 1 && args[0].nil?)

        low, high = convert(args[0])
        low, high = convert(args[1], low, high) if /[=~><]/.match?(args[1])
        (low == high) ? low : "#{low || '[0'},#{high || ')'}"
      end

      private

      def convert(arg, low = nil, high = nil)
        if arg.include?('~>')
          val = arg.sub(/~>\s*/, '')
          last = val.include?('.') ? val.sub(/\.[0-9]*[a-z]+.*$/, '').sub(/\.[^.]+$/, '.99999') : '99999'
          ["[#{snapshot_version(val)}", "#{snapshot_version(last)}]"]
        elsif arg.include?('>=')
          val = arg.sub(/>=\s*/, '')
          ["[#{snapshot_version(val)}", high]
        elsif arg.include?('<=')
          val = arg.sub(/<=\s*/, '')
          [low, "#{snapshot_version(val)}]"]
        # treat '!' the same way as '>' since maven cannot describe such range
        elsif /[!>]/.match?(arg)
          val = arg.sub(/[!>]\s*/, '')
          ["(#{snapshot_version(val)}", high]
        elsif arg.include?('<')
          val = arg.sub(/<\s*/, '')
          [low, "#{snapshot_version(val)})"]
        elsif arg.include?('=')
          val = arg.sub(/=\s*/, '')
          # for prereleased version pick the maven version (no version range)
          if /[a-z]|[A-Z]/.match?(val)
            [val, val]
          else
            ["[#{val}", "#{val}.0.0.0.0.1)"]
          end
        else
          # no conversion here, i.e. assume maven version
          [arg, arg]
        end
      end

      def snapshot_version(val)
        if val.match(/[a-z]|[A-Z]/) && !val.match(/-SNAPSHOT|[${}]/)
          "#{val}-SNAPSHOT"
        else
          val
        end
      end
    end
  end

  class GemspecArtifacts
    class Exclusion
      attr_reader :group_id, :artifact_id

      def initialize(line)
        @group_id, @artifact_id = line.gsub(/['"]/, '').strip.split(':')
        @artifact_id.strip!
      end

      def to_s
        "#{@group_id}:#{@artifact_id}"
      end
    end

    class Exclusions < Array
      def to_s
        "[#{join(', ')}]"
      end

      def initialize(line)
        super()
        line.gsub(/'"|^\s*\[|\]\s*$/, '').split(/,\s*/).each do |exclusion|
          self << Exclusion.new(exclusion)
        end
        freeze
      end
    end

    class Artifact
      attr_reader :type, :group_id, :artifact_id, :classifier, :version, :scope, :exclusions

      ALLOWED_TYPES = %w[jar pom].freeze

      def initialize(type, group_id, artifact_id, classifier, version, exclusions, **options)
        @type = type
        @group_id = group_id
        @artifact_id = artifact_id
        @classifier = classifier
        @version = version
        @exclusions = exclusions
        options.each do |k, v|
          instance_variable_set(:"@#{k}", v)
        end
      end

      def self.parse(line)
        line = line.strip
        index = line.index(/\s/)
        return nil if index.nil?

        type = line[0..index].strip
        return nil unless ALLOWED_TYPES.member?(type)

        line = line[index..]
        line.gsub!(/['"]/, '')
        line.strip!

        options = {}
        line.sub!(/,\s*:exclusions\s*(:|=>)\s*(\[[^\]]+\])/) do
          options[:exclusions] = Exclusions.new(Regexp.last_match(2).strip)
          ''
        end
        line.sub!(/,\s*:([a-z]+)\s*(:|=>)\s*(:?[a-zA-Z0-9_]+)/) do
          options[Regexp.last_match(1).to_sym] = Regexp.last_match(3).sub(/^:/, '')
          ''
        end
        exclusions = nil
        line.sub!(/[,:]\s*\[(.+:.+,?\s*)+\]$/) do |a|
          exclusions = Exclusions.new(a[1..].strip)
          ''
        end

        line.strip!
        line.gsub!(/,\s*/, ':')

        if /[\[()\]]/.match?(line)
          index = line.index(/[\[(].+$/)
          version = line[index..].sub(':', ', ')
          line = line[0..(index - 1)].strip.sub(/:$/, '')
        else
          index = line.index(/:[^:]+$/)
          version = line[(index + 1)..]
          line = line[0..(index - 1)].strip
        end

        case line.count(':')
        when 2
          group_id, artifact_id, classifier = line.split(':')
        when 1
          group_id, artifact_id = line.split(':')
          classifier = nil
        else
          warn line
          return nil
        end
        new(type, group_id, artifact_id, classifier, version, exclusions, **options)
      end

      def to_s
        args = [@group_id, @artifact_id]
        args << @classifier if @classifier
        args << @version
        args << @exclusions.to_s if @exclusions
        "#{@type} #{group_id}:#{args[1..].join(', ')}"
      end

      def to_gacv
        args = [@group_id, @artifact_id]
        args << @classifier if @classifier
        args << @version
        args.join(':')
      end

      def to_coord(classifier: true)
        args = [@group_id, @artifact_id]
        args << @classifier if classifier && @classifier
        args << @type
        args << MavenVersion.resolve(@version)
        args.join(':')
      end

      def key
        args = [@group_id, @artifact_id]
        args << @classifier if @classifier
        args.join(':')
      end
    end

    attr_reader :artifacts

    def initialize(spec)
      @artifacts = []
      spec.requirements.each do |req|
        req.split("\n").each do |line|
          artifact = Artifact.parse(line)
          @artifacts << artifact if artifact
        end
      end
      @artifacts.freeze
    end

    def [](index)
      @artifacts[index]
    end

    def each(&block)
      @artifacts.each(&block)
    end

    def size
      @artifacts.size
    end
  end
end
