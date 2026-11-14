
## Add pony-mutate as an optional ponyc binary

When installing or updating ponyc, ponyup now creates a symlink for `pony-mutate` if the binary is present in the package. Like `pony-lsp`, `pony-lint`, `pony-doc`, and `pony-agent-server`, it is optional — ponyup skips it without error when the package does not include it.
