## Use `XDG_DATA_HOME` for install prefix in init script when set

The `ponyup_init.sh` script will now set the default install prefix to the `XDG_DATA_HOME` environment variable if the variable is set.

## Select uses latest version if none is specified

The select command will now link the latest installed version of a given package by default. For example, if `ponyc-release-0.36.0-x86_64-linux-gnu` is the latest release version of ponyc installed then it can now be selected with the command `ponyup select ponyc release` or the command `ponyup select ponyc release-latest`.
# Update Dockerfile to Alpine 3.12

The ponyup Docker container has been updated from being based on Alpine 3.11 to Alpine 3.12. This shouldn't be a breaking change for pretty much anyone, but might be if you are using the ponyup image as a base for other images and some package you rely on was removed from Alpine 3.12.

