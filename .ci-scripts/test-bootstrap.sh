#!/bin/sh

set -e

if ! command -v python3 >/dev/null 2>&1; then
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache python3
  else
    apt-get update
    apt-get install -y --no-install-recommends python3
  fi
fi

prefix=$(mktemp -d)
trap 'rm -rf "${prefix}"' EXIT
root="$prefix/ponyup"
old=ponyup-release-0.0.1-x86_64-linux
other=corral-release-0.0.1-x86_64-linux
mkdir -p "$root/$old/bin" "$root/$other/bin"
printf '%s *\n' "$old" "$other" > "$root/.lock"
./ponyup-init.sh --prefix="$prefix"
"$root/bin/ponyup" version
./ponyup-init.sh --prefix="$prefix" --repository=nightlies
grep -Fxq "$old" "$root/.lock"
grep -Fxq "$other *" "$root/.lock"
grep -Eq '^ponyup-nightly-[0-9]{8}-[^ ]+ \*$' "$root/.lock"

MAKE=${MAKE:=make}
SSL=${SSL:=1.1.x}
export PATH="$root/bin:$PATH"
ponyup version

if [ -n "${PLATFORM}" ]; then
  ponyup --prefix="$prefix" default "${PLATFORM}"
fi

platform=$(cat "$root/.platform")
python3 .ci-scripts/install-pony-tools.py "$platform" nightly nightly
export PATH="/tmp/ponyc/bin:/tmp/corral/bin:$PATH"

${MAKE} clean
${MAKE} ssl="${SSL}"

if build/release/ponyup --prefix="$prefix" find corral private > "$prefix/error" 2>&1; then
  exit 1
fi
grep -Fq -- '--source=cloudsmith' "$prefix/error"

build/release/ponyup --prefix="$prefix" update ponyc nightly --api-timeout 120 --retries 3
build/release/ponyup --prefix="$prefix" update corral nightly --api-timeout 120 --retries 3
"$root/bin/ponyc" --version
"$root/bin/corral" version
