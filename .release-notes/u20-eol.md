## Drop Ubuntu 20.04 support

Ubuntu 20.04 has reached its end of life date. We've dropped it as a supported platform for `ponyc` and `ponyup`.

For `ponyup` that means, we no longer test against it when doing CI. Additinally, new installations of `ponyup` on Ubuntu 20.04 and related platforms won't recognize it as a supported package. If you install `ponyup` on such a platform, you'll need to set the platform to `ubuntu20.04` yourself.

For `ponyc` the lack of support means that if you are using `ponyup` on Ubuntu 20.04 that it won't be able to install any version of `ponyc` from the point that we stopped supporting 20.04 for `ponyc`. Any `ponyc` after 0.59.0 on will not be able to be installed via `ponyup` and will need to instead be built from source.
