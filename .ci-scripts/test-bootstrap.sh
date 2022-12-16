#!/bin/sh

./ponyup-init.sh --repository=nightlies

MAKE=${MAKE:=make}
SSL=${SSL:=1.1.x}

export PATH=$HOME/.local/share/ponyup/bin:$PATH

if [ -n "${PLATFORM}" ]; then
  ponyup default "${PLATFORM}"
fi

ponyup update ponyc nightly
ponyup update corral nightly

${MAKE} clean
${MAKE} ssl=${SSL}
