## Drop Fedora 41 support

Fedora 41 is about to reach its end of life date. We've dropped it as a supported platform for `ponyc` and `ponyup`.

For `ponyup` that means, we no longer test against it when doing CI. Additinally, new installations of `ponyup` on Fedora 41 and related platforms won't recognize it as a supported package. If you install `ponyup` on such a platform, you'll need to set the platform to `fedora41` yourself.

For `ponyc` the lack of support means that if you are using `ponyup` on Fedora 41 that it won't be able to install any version of `ponyc` from the point that we stopped supporting Fedora 41 for `ponyc`. Any `ponyc` after 0.60.3 will not be able to be installed via `ponyup` and will need to instead be built from source.

