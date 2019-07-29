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

check_output() {
  cmd=$1
  expected=$2

  output=$($cmd | tee /dev/tty)
  if ! echo "$output" | grep -q "$expected"; then
    printf "\\033[1;91m  ===> error:\\033[0m did not match \"%s\"\n" \
      "${expected}"
    exit 1
  fi
}

test_title() {
  title=$1
  printf "\\033[1;32m==============================\n"
  printf "  Test: %s\n" "${title}"
  printf "==============================\\033[0m\n"
}

prefix="./.pony_test"
today=$(date +%Y%m%d)
yesterday=$(date +%Y%m%d --date="yesterday")

test_title "version"
check_output "./build/ponyup version" "ponyup 0.0.1"

test_title "nightly"
ponyup_test "update nightly --verbose" \
  "$prefix/ponyup/nightly-$today/bin/ponyc"

test_title "up to date"
check_output "./build/ponyup update -v -p=$prefix nightly" \
  "nightly is up to date"

test_title "nightly (yesterday)"
ponyup_test "update nightly-$yesterday" \
  "$prefix/ponyup/nightly-$today/bin/ponyc"
