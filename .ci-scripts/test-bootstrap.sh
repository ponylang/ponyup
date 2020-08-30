#!/bin/sh

./ponyup-init.sh --repository=nightlies

export PATH=$HOME/.local/share/ponyup/bin:$PATH

if [ -n "${PLATFORM}" ]; then
  ponyup default "${PLATFORM}"
fi

ponyup update ponyc nightly
ponyup update changelog-tool nightly
ponyup update corral nightly
ponyup update stable nightly

make clean
make
