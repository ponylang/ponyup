## Fix crash when closing a connection before initialization completes

Closing a connection before its internal initialization completed could cause a crash. This was a rare race condition most likely to occur on macOS arm64.

## Remove `--platform` option

The `--platform` option has been removed from the `find`, `remove`, `update`, and `select` commands. Platform is now always determined from the `.platform` file in ponyup's data directory. If you don't have a `.platform` file, use `ponyup default` to create one:

```sh
ponyup default x86_64-linux-ubuntu24.04
```

The `ponyup version` and `ponyup default` commands no longer require a `.platform` file to be present.

## Separate channel and version into distinct CLI arguments

The `update`, `select`, and `remove` commands previously required channel and version to be joined with a dash into a single argument. That was confusing and didn't match how you'd naturally think about the command. Channel and version are now separate arguments, with version being optional (defaults to latest).

Before:

```sh
ponyup update ponyc release-0.33.1
ponyup select ponyc nightly-20191116
ponyup remove ponyc release-0.33.1
```

After:

```sh
ponyup update ponyc release 0.33.1
ponyup select ponyc nightly 20191116
ponyup remove ponyc release 0.33.1
```

If you omit the version, you get the latest available, same as before:

```sh
ponyup update ponyc release
```

