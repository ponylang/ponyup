## Drop Fedora 39 support

Fedora 39 has reached its end of life date. We've dropped it as a supported platform for `ponyc` and `ponyup`.

For `ponyup` that means, we no longer test against it when doing CI. Additinally, new installations of `ponyup` on Fedora 39 and related platforms won't recognize it as a supported package. If you install `ponyup` on such a platform, you'll need to set the platform to `fedora39` yourself.

For `ponyc` the lack of support means that if you are using `ponyup` on Fedora 39 that it won't be able to install any version of `ponyc` from the point that we stopped supporting Fedora 39 for `ponyc`. Any `ponyc` from 0.58.8 on will not be able to be installed via `ponyup` and will need to instead be built from source.
