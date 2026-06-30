# frozen_string_literal: true

gemfile

plugin_repository id: :mavengems, url: 'mavengem:https://rubygems.org'

jruby_plugin(:minitest, minispecDirectory: 'specs/*_spec.rb') do
  execute_goals(:spec)
end

properties('jruby.versions' => ['${jruby.version}'].join(','),
           # just lock the version
           'bundler.version' => '2.5.11',
           'jruby.version' => '9.4.8.0',
           'jruby.plugins.version' => '3.0.2',
           'push.skip' => true)

plugin :invoker, '1.8' do
  execute_goals(:install, :run,
                id: 'integration-tests',
                projectsDirectory: 'integration',
                streamLogs: true,
                goals: ['install'],
                preBuildHookScript: 'setup.bsh',
                postBuildHookScript: 'verify.bsh',
                cloneProjectsTo: '${project.build.directory}',
                properties: { 'jar-dependencies.version' => '${project.version}',
                              # use an old jruby with old ruby-maven here
                              'jruby.version' => '${jruby.version}',
                              'jruby.plugins.version' => '${jruby.plugins.version}',
                              'bundler.version' => '${bundler.version}', })
end

distribution_management do
  repository id: :ossrh, url: 'https://oss.sonatype.org/service/local/staging/deploy/maven2/'
end

profile id: :skip do
  properties 'maven.test.skip' => true, 'invoker.skip' => true
end

profile id: :release do
  properties 'maven.test.skip' => true, 'invoker.skip' => true, 'push.skip' => false

  build do
    default_goal :deploy
  end
end
