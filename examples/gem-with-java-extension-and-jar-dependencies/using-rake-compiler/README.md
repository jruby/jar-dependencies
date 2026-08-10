# building a gem with jar dependencies

## setup

```
bundle install
```

which is important since it will create a file lib/gem-name_jars.rb
and installs the jar dependencies into a local cache (local maven repository)

## lock down version of jar dependencies

lock down may or may not be needed (best just lock them down). in case you want to lock down your versions for the jars execute:

```
lock_jars
```

## build compile and create jar

```
rake compile
```

## use it

```
jruby test.rb
```

## pack gem

```
rake package
```
