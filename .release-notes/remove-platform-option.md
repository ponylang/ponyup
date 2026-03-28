## Remove `--platform` option

The `--platform` option has been removed from the `find`, `remove`, `update`, and `select` commands. Platform is now always determined from the `.platform` file in ponyup's data directory. If you don't have a `.platform` file, use `ponyup default` to create one:

```sh
ponyup default x86_64-linux-ubuntu24.04
```

The `ponyup version` and `ponyup default` commands no longer require a `.platform` file to be present.
