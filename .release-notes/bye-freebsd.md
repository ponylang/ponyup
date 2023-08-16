## Drop FreeBSD support

We no longer have any CI resources for maintaining FreeBSD versions of Pony tools. We've dropped FreeBSD as a fully-supported platform for `ponyc`, `corral`, and `ponyup`.

For `ponyup` that means, we no longer test against it when doing CI. Additinally, new installations of `ponyup` on FreeBSD. If you install `ponyup` on such a platform, you'll need to set the platform yourself.

For `ponyc` the lack of support means that if you are using `ponyup` on FreeBSD that it won't be able to install any version of `ponyc` from the point that we stopped supporting it for `ponyc`. Any `ponyc` from 0.56.0 on will not be able to be installed via `ponyup` and will need to instead be built from source.
