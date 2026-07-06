# frozen_string_literal: true
require 'bundler/setup'

ENV['JARS_HOME'] = nil
require 'jar_dependencies'

p ENV['JARS_LOCAL_MAVEN_REPO'] = Jars.home
Jars.reset

require 'minitest/autorun'
