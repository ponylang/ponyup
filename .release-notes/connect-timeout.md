## Add connection timeout

ponyup now enforces a connection timeout when contacting the Cloudsmith package server. If the server is unreachable or the connection handshake takes too long, ponyup will fail with an error instead of hanging indefinitely.

The default timeout is 30 seconds. Override it with `--connect-timeout`:

```sh
ponyup --connect-timeout 60 update ponyc release
```

Valid values are 1 to 300 seconds.
