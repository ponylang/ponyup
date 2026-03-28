#!/bin/sh

# ponyup-init.sh uses set -o nounset and references $SHELL to print
# PATH instructions. In CI containers $SHELL is unset, so the script
# exits non-zero even though ponyup was installed successfully.
# We allow that failure but verify ponyup is on PATH afterward.
./ponyup-init.sh --repository=nightlies || true

MAKE=${MAKE:=make}
SSL=${SSL:=1.1.x}

export PATH=$HOME/.local/share/ponyup/bin:$PATH

if [ -n "${PLATFORM}" ]; then
  ponyup default "${PLATFORM}"
fi

set -e

ponyup update ponyc nightly --api-timeout 120
ponyup update corral nightly --api-timeout 120

${MAKE} clean
${MAKE} ssl=${SSL}
