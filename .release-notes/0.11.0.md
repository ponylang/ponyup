## Drop Fedora 41 support

Fedora 41 is about to reach its end of life date. We've dropped it as a supported platform for `ponyc` and `ponyup`.

For `ponyup` that means, we no longer test against it when doing CI. Additinally, new installations of `ponyup` on Fedora 41 and related platforms won't recognize it as a supported package. If you install `ponyup` on such a platform, you'll need to set the platform to `fedora41` yourself.

For `ponyc` the lack of support means that if you are using `ponyup` on Fedora 41 that it won't be able to install any version of `ponyc` from the point that we stopped supporting Fedora 41 for `ponyc`. Any `ponyc` after 0.60.3 will not be able to be installed via `ponyup` and will need to instead be built from source.

## Support applications installing more than 1 binary

The original design of ponyup was that you would install an application such as ponyc that in turn contained a single binary that shared the same name.

We recently started including the Pony language server in the distribution with ponyc. Ponyup could install the distribution but would only install into the user's PATH the ponyc binary.

We've added support for application distributions to contain more than one binary that will be linked into the user's PATH.

The practical implication is that when you install a ponyc distribution that also contains `pony-lsp`, both `ponyc` and `pony-lsp` will be available via your PATH.

