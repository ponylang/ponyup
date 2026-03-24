## Add connection timeout

ponyup now enforces a connection timeout when contacting the Cloudsmith package server. If the server is unreachable or the connection handshake takes too long, ponyup will fail with an error instead of hanging indefinitely.

The default timeout is 30 seconds. Override it with `--connect-timeout`:

```sh
ponyup --connect-timeout 60 update ponyc release
```

Valid values are 1 to 300 seconds.

## Add request timeouts

ponyup now enforces wall-clock timeouts on HTTP requests. If a Cloudsmith API query or package download takes too long, ponyup will fail with an error instead of hanging indefinitely.

Two new options control the deadlines:

- `--api-timeout` sets the timeout for API queries (default: 15 seconds, range: 1-300)
- `--download-timeout` sets the timeout for package downloads (default: 300 seconds, range: 60-7200)

```sh
ponyup --api-timeout 30 show
ponyup --download-timeout 600 update ponyc release
```

## Wait for all API queries before displaying results

`ponyup show` and `ponyup find` previously displayed partial results after a fixed delay (5 and 10 seconds respectively), leaving slow queries running in the background. Now they wait for every query to either complete or individually time out via `--api-timeout` (default 15 seconds). The process exits promptly once all queries finish instead of lingering while abandoned connections drain.

