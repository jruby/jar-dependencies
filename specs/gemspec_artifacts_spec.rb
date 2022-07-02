# frozen_string_literal: true

require File.expand_path('setup', File.dirname(__FILE__))

require 'jars/gemspec_artifacts'

describe Jars::GemspecArtifacts::Exclusion do
  it 'parse and to_s of exclusion' do
    expected = 'group:artifact'
    line = ' group:artifact '
    ex = Jars::GemspecArtifacts::Exclusion.new(line)
    ex.to_s.must_equal expected
    line = ' "group:artifact" '
    ex = Jars::GemspecArtifacts::Exclusion.new(line)
    ex.to_s.must_equal expected
    line = "'group:artifact'"
    ex = Jars::GemspecArtifacts::Exclusion.new(line)
    ex.to_s.must_equal expected
    line = ' group:artifact '
    ex = Jars::GemspecArtifacts::Exclusion.new("#{line} :extra:asd")
    ex.to_s.must_equal expected
  end
end

describe Jars::GemspecArtifacts::Exclusions do
  it 'parse and to_s of single exclusion' do
    expected = '[group:artifact]'
    line = ' [group:artifact] '
    ex = Jars::GemspecArtifacts::Exclusions.new(line)
    ex.to_s.must_equal expected
    line = " [' group:artifact'] "
    ex = Jars::GemspecArtifacts::Exclusions.new(line)
    ex.to_s.must_equal expected
    line = ' [ "group:artifact "] '
    ex = Jars::GemspecArtifacts::Exclusions.new(line)
    ex.to_s.must_equal expected
    expected = '[group-id:artifact-id]'
    line = ' [ "group-id:artifact-id "] '
    ex = Jars::GemspecArtifacts::Exclusions.new(line)
    ex.to_s.must_equal expected
  end

  it 'parse and to_s of list of exclusions' do
    expected = '[group1:artifact1, group2:artifact2]'
    line = ' [group1:artifact1, group2:artifact2] '
    ex = Jars::GemspecArtifacts::Exclusions.new(line)
    ex.to_s.must_equal expected
    line = " ['group1:artifact1', ' group2:artifact2'] "
    ex = Jars::GemspecArtifacts::Exclusions.new(line)
    ex.to_s.must_equal expected
    line = ' [ "group1:artifact1", " group2:artifact2"] '
    ex = Jars::GemspecArtifacts::Exclusions.new(line)
    ex.to_s.must_equal expected
  end
end

describe Jars::GemspecArtifacts::Artifact do
  it 'ignore unknow type' do
    Jars::GemspecArtifacts::Artifact.new('bla').must_be_nil
    Jars::GemspecArtifacts::Artifact.new(' bla').must_be_nil
    Jars::GemspecArtifacts::Artifact.new('bla bla bla').must_be_nil
  end

  %i[jar pom].each do |type|
    it "parse and to_s of simple GAV #{type}" do
      expected = "#{type} g:a, 1"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      line = "#{type} 'g:a', '1'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g,a,1"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} 'g',\"a\", 1"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g:a:1"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} 'g:a:1'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end

    it "parse and to_s of simple GAV #{type} with range" do
      expected = "#{type} g:a, [1, 2)"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      line = "#{type} g:a:[1, 2)"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g:a,'[1, 2)'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} 'g', \"a\", ' [1, 2) '"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end

    it "parse and to_s of simple GAV #{type} with one exclusion" do
      expected = "#{type} g:a, 1, [a:b]"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      line = "#{type} 'g:a', '1', '[a:b]'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} 'g:a', '1', ['a:b']"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g,a,1,[a:b]"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end

    it "parse and to_s of simple GAV #{type} with exclusions" do
      expected = "#{type} g:a, 1, [a:b, c:d]"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      line = "#{type} 'g:a', '1', ['a:b', 'c:d']'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g,a,1,[a:b,c:d]"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end

    it "parse and to_s of simple GAV #{type} with exclusions and range" do
      expected = "#{type} g:a, (1, 2], [a:b, c:d]"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      line = "#{type} 'g:a', '(1,2]', ['a:b', 'c:d']'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g,a,(1,2],[a:b,c:d]"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g,a,(1,2],  :exclusions : [a:b,c:d]"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end

    it "parse and to_s of simple GACV #{type}" do
      expected = "#{type} g:a, c, 1"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      line = "#{type} 'g:a', 'c', '1'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} g,a,\"c\",1"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type}  g,a, 1  ,:classifier : c"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end

    it "parse and to_s of simple GACV #{type} with range" do
      expected = "#{type} g:a, c, [1, 2)"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      a.scope.must_be_nil
      line = "#{type} g:a:c:[1, 2),:scope=>:runtime"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      a.scope.must_equal 'runtime'
      line = "#{type} g:a:c,'[1, 2)'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type} 'g', \"a\", 'c', ' [1, 2) '"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      line = "#{type}  g,a,[1,  2),:classifier => c"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end

    it "parse and to_s of simple GACV #{type} with exclusions and range" do
      expected = "#{type} g:a, c, (1, 2], [a:b, c:d]"
      a = Jars::GemspecArtifacts::Artifact.new(expected)
      a.to_s.must_equal expected
      a.scope.must_be_nil
      line = "#{type} 'g:a:c', '(1,2]', ['a:b', 'c:d']'"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      a.scope.must_be_nil
      line = "#{type} g,a,c,(1,2],[a:b,c:d], :scope => :compile"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
      a.scope.must_equal 'compile'
      line = "#{type}  g,a,(1,2],:classifier => c,:exclusions => [a:b,c:d]"
      a = Jars::GemspecArtifacts::Artifact.new(line)
      a.to_s.must_equal expected
    end
  end
end

describe Jars::GemspecArtifacts do
  let(:pwd) { File.dirname(File.expand_path(__FILE__)) }

  let(:example_spec) { File.join(pwd, '..', 'example', 'example.gemspec') }

  it 'retrieves artifacts from gemspec' do
    spec = Dir.chdir(File.dirname(example_spec)) do
      eval(File.read(example_spec)) # rubocop:disable Security/Eval
    end
    artifacts = Jars::GemspecArtifacts.new(spec)
    artifacts[0].to_s.must_equal('jar org.bouncycastle:bcpkix-jdk15on, 1.49')
    artifacts[1].to_s.must_equal('jar org.bouncycastle:bcprov-jdk15on, 1.49')
    artifacts[3].to_s.must_equal('jar io.dropwizard:dropwizard-logging, 0.8.0-rc5, [joda-time:joda-time]')
    artifacts[4].to_s.must_equal('jar com.google.protobuf:protobuf-java, lite, 2.2.0')
    artifacts[5].to_s.must_equal('jar junit:junit, 4.12')
    artifacts[0].scope.must_be_nil
    artifacts[1].scope.must_be_nil
    artifacts[2].scope.must_be_nil
    artifacts[3].scope.must_be_nil
    artifacts[4].scope.must_be_nil
    artifacts[5].scope.must_equal('test')
    artifacts[0].classifier.must_be_nil
    artifacts[1].classifier.must_be_nil
    artifacts[2].classifier.must_be_nil
    artifacts[3].classifier.must_be_nil
    artifacts[4].classifier.must_equal('lite')
    artifacts[5].classifier.must_be_nil
    artifacts[0].exclusions.must_be_nil
    artifacts[1].exclusions.must_be_nil
    artifacts[2].exclusions.must_be_nil
    artifacts[3].exclusions.to_s.must_equal('[joda-time:joda-time]')
    artifacts[4].exclusions.must_be_nil
    artifacts[5].exclusions.must_be_nil

    artifacts.each do |a|
      a.to_s.must_equal Jars::GemspecArtifacts::Artifact.new(a.to_s).to_s
    end

    artifacts.size.must_equal 7
  end
end
