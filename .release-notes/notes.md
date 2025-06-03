## Add Support for Alpine 3.20 on x86-64

We've added support for Alpine 3.20 on x86-64. We are moving away from having generic "musl-libc" packages as they aren't guaranteed to work on all musl-libc systems unless everything is statically linked which in the case of the Pony compiler is not the case. This means that if you are using `ponyup` on an x86-64 system with Alpine 3.20, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.
