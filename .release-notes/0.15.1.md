## Handle unset $SHELL in ponyup-init.sh

The ponyup-init.sh bootstrap script would crash in environments where the `SHELL` environment variable is not set, such as Docker containers. The script had already successfully installed ponyup at that point — the crash occurred while printing PATH setup instructions. ponyup-init.sh now handles an unset `SHELL` gracefully.

## Add --retries flag for update command

`ponyup update` now accepts a `--retries` flag that retries on transient failures. Both Cloudsmith API queries (connection failures, timeouts) and package downloads (connection failures, timeouts, checksum mismatches) are retried. Each retry waits 3 seconds before the next attempt. The default is 0 (no retries), preserving current behavior.

```sh
ponyup update ponyc release --retries 3
```

Queries that succeed but return no results (e.g., a non-existent package version) are not retried.

