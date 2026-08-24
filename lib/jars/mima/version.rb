# frozen_string_literal: true

module Jars
  module Mima
    MIMA_VERSION = '2.4.48'
    SLF4J_VERSION = '2.0.18'

    MAVEN_CENTRAL = 'https://repo.maven.apache.org/maven2'
    MIMA_DIR = 'lib/jars/mima'

    # GAV and SHA-1 checksum (as published on Maven Central) for each jar
    jars = %w[
      org.slf4j:slf4j-api:2.0.18
      78a9e7a37cd6360e0b818e86341b24123d28d4df

      org.slf4j:slf4j-simple:2.0.18
      503354e24cb3a2c61f808a83934b76c2dc4ec4d8

      org.slf4j:jcl-over-slf4j:2.0.18
      fb36c10c70e27bb427bb3cec86ac30bb83f667c7

      eu.maveniverse.maven.mima:context:2.4.48
      e792b92b226c2bdc829030c19f1239553dc1e382

      eu.maveniverse.maven.mima.runtime:standalone-static-uber:2.4.48
      b2bb20acce196213d1cbd39cbe1cdb76d8a6b67b
    ]

    JARS = jars.each_slice(2).to_h do |gav, sha1|
      group, artifact, version = gav.split(':')
      group = group.tr('.', '/')
      jar_file = "#{artifact}-#{version}.jar"
      [
        jar_file,
        {
          url: "#{MAVEN_CENTRAL}/#{group}/#{artifact}/#{version}/#{jar_file}",
          sha1: sha1
        }
      ]
    end
  end
end
