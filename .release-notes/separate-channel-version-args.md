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
