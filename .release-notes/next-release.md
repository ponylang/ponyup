## Switch supported MacOS version to Ventura

We've switched our supported MacOS version from Monterey to Ventura.

"Supported" means that all ponyup changes are tested on Ventura rather than Monterey and our pre-built ponyup distribution is built on Ventura.

## Drop Ubuntu 18.04 support

Ubuntu 18.04 has reached its end of life date. We've dropped it as a supported platform for `ponyc` and `ponyup`.

For `ponyup` that means, we no longer test against it when doing CI. Additinally, new installations of `ponyup` on Ubuntu 18.04 and related platforms won't recognize it as a supported package. If you install `ponyup` on such a platform, you'll need to set the platform to `ubuntu18.04` yourself.

For `ponyc` the lack of support means that if you are using `ponyup` on Ubuntu 18.04 that it won't be able to install any version of `ponyc` from the point that we stopped supporting 18.04 for `ponyc`. Any `ponyc` from 0.55.0 on will not be able to be installed via `ponyup` and will need to instead be built from source.

