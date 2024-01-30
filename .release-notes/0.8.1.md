## Use Alpine 3.18 as our base image

Previously we were using Alpine 3.16. This should have no impact on anyone unless they are using this image as the base image for another.

## Add Fedora 39 support

We've added support for identifying Fedora 39 and downloading packages for it. As of the time of this release, no release versions of `ponyc` are available- only nightly versions. Release versions of `ponyc` will be available once a version of `ponyc` post 0.58.1 is released.

