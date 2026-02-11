## Add `remove` command to uninstall package versions

Previously, installed package versions accumulated on disk with no way to clean them up. The new `ponyup remove` command deletes a specific installed version from both disk and the lockfile.

```
ponyup remove ponyc release-0.58.13
ponyup remove ponyc nightly
```

When a bare channel is given (e.g., `nightly`), ponyup resolves it to the latest installed version for that channel — the same behavior as `select`.

Ponyup will refuse to remove the currently selected version. Use `ponyup select` to switch to a different version first.

The `--platform` option is supported, matching the behavior of `select` and `update`.
