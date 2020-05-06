#!/bin/bash

#
# Libresll is required for ponyup
#

brew install libressl

#
# Install ponyup and other tools
#

curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/ponylang/ponyup/latest-release/ponyup-init.sh | sh

export PATH="$HOME/.local/share/ponyup/bin/:$PATH"

ponyup update ponyc release
ponyup update corral release
