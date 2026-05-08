# frozen_string_literal: true

module Jars
  module Mima
    MIMA_VERSION = '2.4.42'
    SLF4J_VERSION = '2.0.17'

    MAVEN_CENTRAL = 'https://repo.maven.apache.org/maven2'
    MIMA_DIR = 'lib/jars/mima'

    # GAV and SHA-1 checksum (as published on Maven Central) for each jar
    jars = %w[
      org.slf4j:slf4j-api:2.0.17
      d9e58ac9c7779ba3bf8142aff6c830617a7fe60f

      org.slf4j:slf4j-simple:2.0.17
      9872a3fd794ffe7b18d17747926a64d61526ca96

      org.slf4j:jcl-over-slf4j:2.0.17
      76ea503eb688f06556a9ba69995d7eab63e34531

      eu.maveniverse.maven.mima:context:2.4.42
      72aa4d9ccef7a329f473e43752ec863c5194c72c

      eu.maveniverse.maven.mima.runtime:standalone-static-uber:2.4.42
      43666099e6eb31610f9d3b146811479dd3e4aef1
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
