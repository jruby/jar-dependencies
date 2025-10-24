# JRuby projects with jar dependencies


```
examples
├── gem-with-jar-dependencies
├── gem-with-java-extension
│   ├── using-maven
│   ├── using-rake-compiler
│   └── using-ruby-maven
├── gem-with-java-extension-and-dependencies
│   ├── using-maven
│   ├── using-rake-compiler
│   └── using-ruby-maven
└── sinatra-app
    ├── having-gems-with-jar-dependencies
    └── having-jarfile-and-gems-with-jar-dependencies
```

to build the java extension you can do it with either proper maven, or
with help of the ruby-maven gem or the rake-compiler gem.

## version ranges against a picked version

jar-dependencies uses maven under the hood to resolve and install jar
dependencies. maven discourages the use of version ranges and without
version ranges there a deterministic version resolution, i.e. there is
way to
[resolve conflicts in maven](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html#Transitive_Dependencies)
(see section 'Dependency mediation').

so if you use version ranges like rubygems does it, then lock down the
versions of jar dependencies is needed. for this use the command

```
lock_jars
```

from the jar-dependencies plugin.

## gem with jar dependencies

see the project here: [gem with jar dependencies](https://github.com/jruby/jar-dependencies/tree/master/examples/gem-with-jar-dependencies)

you need to use bundler in this example. just declare the jar
dependencies inside the gemspec, run

```
bundle install
```

and then you can use them with your ruby code.

with lock down of the jar versions the setup is

```
bundle install
lock_jars
```

## gem with java extension

use can use maven, ruby-maven or rake-compiler to build the
extension. note that there is no jar-dependencies gem involved here.

### using maven

see project here:
[gem with java extension using maven](https://github.com/jruby/jar-dependencies/tree/master/examples/gem-with-java-extension/using-maven)

you need maven 3.9.x installed to get it working and the project needs
to prepare maven to use the ruby DSL for maven. this is done by adding
[](.mvn/extensions.xml) to your project. or use maven wrapper []()

```
bundle install
mvn prepare-package
```

to setup your project.

### using ruby-maven

see project here:
[gem with java extension using ruby-maven](https://github.com/jruby/jar-dependencies/tree/master/examples/gem-with-java-extension/using-ruby-maven)

use the ruby-maven gem instead of system installed maven. much more ruby
like, no need to have anything installed on the system beside jruby, i.e.

```
bundle install
rake compile
```

to setup your project.

### using rake-compiler

see project here:
[gem with java extension using rake-compiler](https://github.com/jruby/jar-dependencies/tree/master/examples/gem-with-java-extension/using-rake-compiler)

just use the rake compiler inside the Rakefile, i.e.

```
bundle install
rake compile
```

to setup your project.

## gem with java extension and jar dependencies

this is more since you might need the jar dependencies and its
transitive dependencies for compiling the gem extension. all these
examples uses the jar dependencies declaration from the gemspec file.

### using maven

see project here:
[gem with java extension and jar dependencies using maven](https://github.com/jruby/jar-dependencies/tree/master/examples/gem-with-java-extension-and-jar-dependencies/using-maven)

maven just sets up the compile classpath for building the extension jar

setup with locked jars

```
bundle install
lock_jars
mvn prepare-package
```

### using ruby-maven

see project here:
[gem with java extension and jar dependencies using ruby-maven](https://github.com/jruby/jar-dependencies/tree/master/examples/gem-with-java-extension-and-jar-dependencies/using-ruby-maven)

like maven but using ruby-maven instrad.

setup with locked jars

```
bundle install
lock_jars
rake compile
```

### using rake-compiler

see project here:
[gem with java extension and jar dependencies using rake-compiler](https://github.com/jruby/jar-dependencies/tree/master/examples/gem-with-java-extension-and-jar-dependencies/using-rake-compiler)

jar-dependencies gems offers a simple way to pass on the classpath to rake-compiler.

setup with locked jars

```
bundle install
lock_jars
rake compile
```

# summary

using rake-compiler or ruby-maven is no difference for the user
setting up the gem.

maven is more to demostrate what is there and it allows to use a gem
project as part of mutli-module maven build keeping the ruby project
as ruby project but still integrate it nicely with maven.
