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

ponyup_bin=build/debug/ponyup
version=$(cut -f 1 <VERSION)

prefix="./.pony_test"
today=$(date +%Y%m%d)
if uname -s | grep -q "Linux"; then
  yesterday=$(date +%Y%m%d --date="yesterday")
else
  yesterday=$(date -v-1d +%Y%m%d)
fi

rm -rf $prefix

test_title "version"
check_output "${ponyup_bin} version" "ponyup ${version}"

test_title "nightly"
${ponyup_bin} update nightly --verbose --prefix="$prefix"
check_file "$prefix/ponyup/nightly-$today/bin/ponyc"
check_file "$prefix/ponyup/nightly-$today/bin/corral"
check_file "$prefix/ponyup/nightly-$today/bin/stable"
check_output "$prefix/ponyup/bin/ponyc --version" "nightly-$today"

test_title "up to date"
check_output "${ponyup_bin} update -v -p=$prefix nightly-$today" \
  "nightly-$today is up to date"
check_file "$prefix/ponyup/nightly-$today/bin/ponyc"
check_file "$prefix/ponyup/nightly-$today/bin/corral"
check_file "$prefix/ponyup/nightly-$today/bin/stable"
check_output "$prefix/ponyup/bin/ponyc --version" "nightly-$today"

test_title "nightly (yesterday)"
${ponyup_bin} -v -p=$prefix update nightly-$yesterday
check_file "$prefix/ponyup/nightly-$yesterday/bin/ponyc"
check_file "$prefix/ponyup/nightly-$yesterday/bin/corral"
check_file "$prefix/ponyup/nightly-$yesterday/bin/stable"
check_output "$prefix/ponyup/bin/ponyc --version" "nightly-$yesterday"
