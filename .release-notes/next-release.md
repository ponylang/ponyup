## Handle unset $SHELL in ponyup-init.sh

The ponyup-init.sh bootstrap script would crash in environments where the `SHELL` environment variable is not set, such as Docker containers. The script had already successfully installed ponyup at that point — the crash occurred while printing PATH setup instructions. ponyup-init.sh now handles an unset `SHELL` gracefully.

