## Wait for all API queries before displaying results

`ponyup show` and `ponyup find` previously displayed partial results after a fixed delay (5 and 10 seconds respectively), leaving slow queries running in the background. Now they wait for every query to either complete or individually time out via `--api-timeout` (default 15 seconds). The process exits promptly once all queries finish instead of lingering while abandoned connections drain.
