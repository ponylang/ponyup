#!/bin/sh

set -e
set -u

check_file() {
  expected=$1

  if [ ! -f "$expected" ]; then
    printf "\\033[1;91m  ===> error:\\033[0m expected file not found: %s\n" \
      "$expected"
    exit 1
  fi
}

check_output() {
  cmd=$1
  expected=$2

  output=$($cmd | tee /dev/tty)
  if ! echo "$output" | grep -q "$expected"; then
    printf "\\033[1;91m  ===> error:\\033[0m did not match \"%s\"\n" \
      "$expected"
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
if uname -s | grep -q "Linux"; then
  yesterday=$(date +%Y%m%d --date="yesterday")
else
  yesterday=$(date -v-1d +%Y%m%d)
fi

rm -rf $prefix

test_title "version"
check_output "./build/ponyup version" "ponyup 0.0.1"

test_title "nightly"
./build/ponyup update nightly --verbose --prefix="$prefix"
check_file "$prefix/ponyup/nightly-$today/bin/ponyc"
check_file "$prefix/ponyup/nightly-$today/bin/stable"
check_output "$prefix/ponyup/bin/ponyc --version" "nightly-$today"

test_title "up to date"
check_output "./build/ponyup update -v -p=$prefix nightly-$today" \
  "nightly-$today is up to date"
check_file "$prefix/ponyup/nightly-$today/bin/ponyc"
check_file "$prefix/ponyup/nightly-$today/bin/stable"
check_output "$prefix/ponyup/bin/ponyc --version" "nightly-$today"

# test_title "nightly (yesterday)"
# ponyup_test "update nightly-$yesterday" \
#   "$prefix/ponyup/nightly-$yesterday/bin/ponyc"
# check_output "$prefix/ponyup/bin/ponyc --version" "nightly-$yesterday"
