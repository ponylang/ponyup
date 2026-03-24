## Add request timeouts

ponyup now enforces wall-clock timeouts on HTTP requests. If a Cloudsmith API query or package download takes too long, ponyup will fail with an error instead of hanging indefinitely.

Two new options control the deadlines:

- `--api-timeout` sets the timeout for API queries (default: 15 seconds, range: 1-300)
- `--download-timeout` sets the timeout for package downloads (default: 300 seconds, range: 60-7200)

```sh
ponyup --api-timeout 30 show
ponyup --download-timeout 600 update ponyc release
```
