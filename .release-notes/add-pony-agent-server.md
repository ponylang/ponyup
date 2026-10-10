## Add pony-agent-server as an optional ponyc binary

When installing or updating ponyc, ponyup now creates a symlink for `pony-agent-server` if the binary is present in the package. Like `pony-lsp`, `pony-lint`, and `pony-doc`, it is optional — ponyup skips it without error when the package does not include it.
