#!/bin/sh

cat ponyup-init.sh | sh -s

export PATH=$HOME/.local/share/ponyup/bin:"/Users/runner/Library/Application Support/ponyup/bin":$PATH
ponyup update ponyc nightly
ponyup update changelog-tool nightly
ponyup update corral nightly
ponyup update stable nightly

make clean
make
