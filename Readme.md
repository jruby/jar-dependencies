# jar-dependencies

[![Gem Version](https://img.shields.io/gem/v/jar-dependencies)](https://rubygems.org/gems/jar-dependencies)
[![Build Status](https://github.com/jruby/jar-dependencies/actions/workflows/main.yml/badge.svg)](https://github.com/jruby/jar-dependencies/actions/workflows/main.yml?query=branch%3Amaster)

Add gem dependencies for jar files to ruby gems.

## Getting control back over your jar

jar dependencies are declared in the gemspec of the gem using the same notation
as [JBundler](https://github.com/jruby/jbundler).

When using `require_jar` to load the jar into JRuby's classloader a version conflict
will be detected and only **ONE** jar gets loaded.
**jbundler** allows to select the version suitable for you application.

Most maven-artifacts do **NOT** use versions ranges but depend on a concrete version.
In such cases **jbundler** can always **overwrite** any such version.


## Vendoring your jars before packing the jar

Add the following to your *Rakefile*:

```ruby
require 'jars/installer'
task :install_jars do
  Jars::Installer.vendor_jars!
end
```

This will install (download) the dependent jars into **JARS_HOME** and create a
file **lib/my_gem_jars.rb**, which will be an enumeration of `require_jars`
statements to load all the jars.
The **vendor_jars** task will copy them into the **lib** directory of the gem.

The location where jars are cached is per default **$HOME/.m2/repository** the
same default as Maven uses to cache downloaded jar-artifacts.
It respects **$HOME/.m2/settings.xml** from Maven with mirror and other settings
or the environment variable **JARS_HOME**.

**IMPORTANT**: Make sure that jar-dependencies is only a **development dependency**
of your gem. If it is a runtime dependency the require_jars file will be overwritten
during installation.


## Reduce the download and reuse the jars from maven local repository

If you do not want to vendor jars into a gem then **jar-dependency** gem can vendor
them when you install the gem. In that case do not use
`Jars::Installer.install_jars` from the above rake tasks.

**NOTE**: Recent JRuby comes with **jar-dependencies** as default gem, for older
versions for the feature to work you need to gem install **jar-dependencies** first
and for bundler need to use the **bundle-with-jars** command instead.

**IMPORTANT**: Make sure that jar-dependencies is a **runtime dependency** of your
gem so the require_jars file will be overwritten during installation with the
"correct" versions of the jars.


## For development you do not need to vendor the jars at all

Set the environment variable

```shell
export JARS_VENDOR=false
```

to tell the jar_installer not vendor any jars, but only create the file with the
`require_jar` statements. This `require_jars` method will find the jar inside the
maven local repository and load it from there.


## Some drawbacks

 * First you need to install the jar-dependency gem with its development dependencies installed (then ruby-maven gets installed as well)
 * Bundler does not install the jar-dependencies (unless JRuby adds the gem as default gem)
 * You need ruby-maven doing the job of dependency resolution and downloading them. gems not part of <http://rubygems.org> will not work currently


## JARs other than from maven-central

By default all jars need to come from maven-central (<search.maven.org>), in order
to use jars from any other repo you need to add it into your Maven *settings.xml*
and configure it in a way that works without an interactive prompt (username +
passwords needs to be part of the settings.xml file).

**NOTE:** Gems depending on jars other then maven-central will **NOT** work when
they get published on rubygems.org since the user of those gems will not have the
right settings.xml to allow them to access the jar dependencies.


## Examples

An [example with rspec and all](example/Readme.md) walks you through setup and
shows how development works and shows what happens during installation.

There are some more examples with the various [project setups for gems and application](examples/README.md).
This includes using proper Maven for the project or ruby-maven with rake or
the rake-compiler in conjunction with jar-dependencies.

# Lock down versions

Whenever there are version ranges for jar dependencies it is advisable to lock down the versions of dependencies.
For the jar dependencies inside the gemspec declaration this can be done with:

```shell
lock_jars
```

This is also working in **any** project which uses a gem with
jar-dependencies. It also uses a Jarfile if present. See the [sinatra
application from the examples](examples/sinatra-app/having-jarfile-and-gems-with-jar-dependencies/).

This means for a project using bundler and jar-dependencies the setup is

```shell
bundle install
lock_jars
```

This will install both gems and jars for the project.

Update a specific version is done with (use only the artifact_id)

```shell
lock_jars --update slf4j-api
```

And look at the dependencies tree

```shell
lock_jars --tree
```

As `lock_jars` uses ruby-maven to resolve the jar dependencies.
Since jar-dependencies does not declare ruby-maven as runtime dependency
(you just not need ruby-maven during runtime only when you want to
setup the project it is needed) it is advicable to have it as
development dependency in your Gemfile.

# Proxy and mirror setup

Proxies and mirrors can be set up by the usual configuration of maven itself: [settings.xml](https://maven.apache.org/settings.html) - see the mirrors and proxy sections.

As jar-dependencies does only deal with jar and all jars need to come from maven central, it is only neccessary to mirror maven-central. An example of such a [settings-example.xml](setting.xml is here).

You also can add such a settings.xml to your project which jar-dependencies will use instad of the default maven locations. This allows to have a per-project configuration and also removes the need to users of your Ruby project to dive into maven in case you have company policy to use a local mirror for gem and jar artifacts.

jar-dependencies itself uses maven **only** for the jars and all gems are managed by RubyGems or Bundler or your favourite management tool. So any proxy/mirror settings which should affect gems need to be done in those tools.

# Gradle, Maven, etc

Dependency management frameworks like gradle (via jruby-gradle-plugin) or maven (via jruby-maven-plugins) can also use gem artifacts retrieved from rubygems.org.

Each of these tools (including jar-dependencies) does the dependency
resolution slightly different and in rare cases can produce different
outcomes. But overall each tool can manage both jars and gems and
their transitive dependencies.

Popular gems like jrjackson or nokogiri do not declare their jars in
the gemspec files and just load the bundle jars into jruby
classloader, can easily create problems as the jackson and
xalan/xerces libraries used by those gems are popular ones in the Java world.

# Troubleshooting

Since maven is used under the hood it is possible to get more insight
what maven is doing. Show the regular maven output:

```shell
JARS_VERBOSE=true bundle install
JARS_VERBOSE=true gem install some_gem
```


Or, with maven debug enabled

```shell
JARS_DEBUG=true bundle install
JARS_DEBUG=true gem install some_gem
```

The maven command line which gets printed needs maven-3.9.x and the
ruby DSL extension for maven:
[polyglot-maven
configuration](https://github.com/takari/polyglot-maven#configuration) where `${maven.multiModuleProjectDirectory}` is
your current directory.

# Configuration

<table border='1'>
<tr>
<td>ENV</td><td>java system property</td><td>default</td><td>description</td>
</tr>
<tr>
<td><tt>JARS_DEBUG</tt></td><td>jars.debug</td><td>false</td><td>if set to true it will produce lots of debug out (maven -X switch)</td>
</tr>
<tr>
<td><tt>JARS_VERBOSE</tt></td><td>jars.verbose</td><td>false</td><td>if set to true it will produce some extra output</td>
</tr>
<tr>
<td><tt>JARS_HOME</tt></td><td>jars.home</td><td>$HOME/.m2/repository</td><td>filesystem location where to store the jar files and some metadata</td>
</tr>
<tr>
<td><tt>JARS_MAVEN_SETTINGS</tt></td><td>jars.maven.settings</td><td>$HOME/.m2/settings.xml</td><td>setting.xml for maven to use</td>
</tr>
<tr>
<td><tt>JARS_VENDOR</tt></td><td>jars.vendor</td><td>true</td><td>set to true means that the jars will be stored in JARS_HOME only</td>
</tr>
<tr>
<td><tt>JARS_SKIP</tt></td><td>jars.skip</td><td>true</td><td>do **NOT** install jar dependencies at all</td>
</tr>
</table>

# Motivation

In 2014, while tools such as [https://github.com/arrigonialberto86/ruby-band](https://github.com/arrigonialberto86/ruby-band) used [jbundler](https://github.com/jruby/jbundler) to manage their there was no easy or formal way to 
- find out which JARs were added to the JRuby classloader
- to manage JRuby projects with Maven
- to build Java/JRuby gem extensions with [rake-compiler](https://github.com/luislavena/rake-compiler/issues/87).

With JRuby 9000 it was the right time to get jar dependencies "right".

# Developing

You must have the latest ruby-maven installed in your local JRuby.

./mvnw install will build the gem and run integration tests
