## Remove macOS on Intel support

We no longer support macOS on Intel. Going forward ponyup will only support macOS on Apple Silicon.

## Stop installing "generic gnu" ponyc builds

Previously, on glibc based Linux distributions, the default setup of ponyup would install the "generic gnu" builds of ponyc. These "generic builds" only work on Linux distributions that are library compatible with the build environment. This use of "generic gnu" made it easy to install a ponyc that wouldn't work on the users platform even if we have ponyc builds for said distribution.

We've stopped using the "generic gnu" builds and instead, on glibc Linux distributions, are using `lsb_release -d` to determine the distribution and if we support the distribution, set up ponyup to install ponyc builds for the distribution in question. If we don't support the distribution or recognize the output of `lsb_release`, an error message is displayed.

