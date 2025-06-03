## Add arm64 Linux builds

We've added arm64 builds for Linux to our release process.

## Add Support for Alpine 3.21 on arm64

We've added support for Alpine 3.21 on arm64. This means that if you are using `ponyup` on an arm64 system with Alpine 3.21, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.

## Add Support for Alpine 3.21 on x86-64

We've added support for Alpine 3.21 on x86-64. We are moving away from having generic "musl-libc" packages as they aren't guaranteed to work on all musl-libc systems unless everything is statically linked which in the case of the Pony compiler is not the case. This means that if you are using `ponyup` on an x86-64 system with Alpine 3.21, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.

## Add Support for Alpine 3.20 on x86-64

We've added support for Alpine 3.20 on x86-64. We are moving away from having generic "musl-libc" packages as they aren't guaranteed to work on all musl-libc systems unless everything is statically linked which in the case of the Pony compiler is not the case. This means that if you are using `ponyup` on an x86-64 system with Alpine 3.20, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.

## Add Support for Ubuntu 24.04 on arm64

We've added support for Ubuntu 24.04 on arm64. This means that if you are using `ponyup` on an arm64 system with Ubuntu 24.04, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.

## Stop having a base image

Previously we were using Alpine 3.20 as the base image for the ponyup container image. We've switched to using the `scratch` image instead. This means that the container image is now much smaller and only contains the `ponyup` binary.

