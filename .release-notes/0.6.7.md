## Add ARM64 support

We updated ponyup to correctly detect arm64 CPUs. Previously, ponyup defaulted to assuming that the current platform was x86_64, even when the user used the `--platform` flag to override this.

## Add support for MacOS on Apple Silicon

You can now use ponyup on Apple Silicon MacOS computers. corral and ponyc are both available to install via ponyup and the ponyup install script recognizes MacOS on Apple Silicon and installs a prebuilt version of ponyup.

