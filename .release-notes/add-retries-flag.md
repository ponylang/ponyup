## Add --retries flag for update command

`ponyup update` now accepts a `--retries` flag that retries on transient failures. Both Cloudsmith API queries (connection failures, timeouts) and package downloads (connection failures, timeouts, checksum mismatches) are retried. Each retry waits 3 seconds before the next attempt. The default is 0 (no retries), preserving current behavior.

```sh
ponyup update ponyc release --retries 3
```

Queries that succeed but return no results (e.g., a non-existent package version) are not retried.
