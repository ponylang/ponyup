## Statically link LibreSSL on macOS

macOS builds of ponyup now statically link LibreSSL instead of dynamically linking against Homebrew's version. Previously, when Homebrew updated LibreSSL to a newer version, existing ponyup binaries would break because the dynamic library version changed. You'd have to reinstall ponyup to get it working again.

With this change, the LibreSSL libraries are baked into the ponyup binary itself. You no longer need to install LibreSSL via Homebrew to use ponyup on macOS, and Homebrew updates won't break your existing installation.

The `ponyup-init.sh` script also now defaults to release builds on macOS instead of nightlies. The nightly default was a workaround for this same problem — nightlies were rebuilt daily against the current Homebrew LibreSSL, so they were less likely to be broken. That workaround is no longer needed.

