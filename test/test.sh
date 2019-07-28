#!/bin/sh

set -e
set -u

ponyup_test() {
  args=$1
  expected=$2

  ./build/ponyup $args --prefix="$prefix"

  if [ ! -f "$expected" ]; then
    echo "expected file not found: $expected"
    exit 1
  fi
}

prefix="./.pony_test"
today=$(date +%Y%m%d)
yesterday=$(date +%Y%m%d --date="yesterday")

[ "$(./build/ponyup version)" = "ponyup 0.0.1" ] || exit 1

ponyup_test "update nightly --verbose" \
  "$prefix/ponyup/nightly-$today/bin/ponyc"

ponyup_test "update nightly-$yesterday" \
  "$prefix/ponyup/nightly-$today/bin/ponyc"
