## Add `find` command to search for available package versions

The new `ponyup find` command queries Cloudsmith to show available versions of a package. Previously, there was no way to discover what versions were available before attempting to install one. Now you can browse available versions to find the one you need.

```
ponyup find ponyc
ponyup find ponyc release
ponyup find corral nightly
```

When no channel is specified, both nightly and release results are shown. Providing a channel filters to just that channel.

### Options

- `--platform` — Search for a specific platform instead of the default (e.g. `--platform=x86_64-linux-ubuntu24.04`)
- `-n` — Number of results to display per channel, default 10, max 500 (e.g. `-n 3`)
- `-a` — Show results for all platforms instead of just the default

## Add `remove` command to uninstall package versions

Previously, installed package versions accumulated on disk with no way to clean them up. The new `ponyup remove` command deletes a specific installed version from both disk and the lockfile.

```
ponyup remove ponyc release-0.58.13
ponyup remove ponyc nightly
```

When a bare channel is given (e.g., `nightly`), ponyup resolves it to the latest installed version for that channel — the same behavior as `select`.

Ponyup will refuse to remove the currently selected version. Use `ponyup select` to switch to a different version first.

The `--platform` option is supported, matching the behavior of `select` and `update`.

