## Support applications installing more than 1 binary

The original design of ponyup was that you would install an application such as ponyc that in turn contained a single binary that shared the same name.

We recently started including the Pony language server in the distribution with ponyc. Ponyup could install the distribution but would only install into the user's PATH the ponyc binary.

We've added support for application distributions to contain more than one binary that will be linked into the user's PATH.

The practical implication is that when you install a ponyc distribution that also contains `pony-lsp`, both `ponyc` and `pony-lsp` will be available via your PATH.
