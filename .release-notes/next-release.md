## Drop Alpine 3.20 Support

Alpine 3.20 is about to reach its end of life date. We've dropped it as a supported platform for `ponyc` and `ponyup`.

For `ponyup` that means, we no longer test against it when doing CI. Additionally, new installations of `ponyup` on Alpine 3.20 won't recognize it as a supported package. If you install `ponyup` on such a platform, you'll need to set the platform to `alpine3.20` yourself.

For `ponyc` the lack of support means that if you are using `ponyup` on Alpine 3.20 that it won't be able to install any version of `ponyc` from the point that we stopped supporting Alpine 3.20 for `ponyc`. Any `ponyc` after 0.62.1 will not be able to be installed via `ponyup` and will need to instead be built from source.

