## Require ponyc 0.64.0 or later

Building ponyup from source now requires ponyc 0.64.0 or later. The previous minimum was 0.63.1.

This is driven by an update to courier 0.3.0, which transitively requires ponyc 0.64.0 via lori 0.15.0 for changes to FFI declaration syntax and the runtime socket API. Older ponyc versions will fail to compile ponyup.

## Add Alpine 3.24 as a supported platform

We've added support for Alpine 3.24. This means that if you are using `ponyup` on an arm64 or amd64 system with Alpine 3.24, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.

