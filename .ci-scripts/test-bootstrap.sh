#!/bin/sh

set -e

./ponyup-init.sh --repository=nightlies

MAKE=${MAKE:=make}
SSL=${SSL:=1.1.x}

export PATH=$HOME/.local/share/ponyup/bin:$PATH

if [ -n "${PLATFORM}" ]; then
  ponyup default "${PLATFORM}"
fi

ponyup update ponyc nightly --api-timeout 120 --retries 3
ponyup update corral nightly --api-timeout 120 --retries 3

${MAKE} clean
${MAKE} ssl=${SSL}
