## Stop Building Ponyup Docker Images

We've stopped building and publishing ponyup docker images. Ponyup is available in the ponyc images and can be used from there. Additionally, the only thing in the images was a statically linked binary, which can be downloaded Cloudsmith or installed using our standard install script. The image itself provided no real value.

## Add Alpine 3.22 as a supported platform

We've added support for Alpine 3.22. This means that if you are using `ponyup` on an arm64 or amd64 system with Alpine 3.22, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.

