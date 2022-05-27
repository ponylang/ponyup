## Add ARM64 support

We updated ponyup to correctly detect arm64 CPUs. Previously, ponyup defaulted to assuming that the current platform was x86_64, even when the user used the `--platform` flag to override this.

