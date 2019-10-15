#!/bin/sh

set -o errexit
set -o nounset

check_file() {
  expected=$1

  if [ ! -f "${expected}" ]; then
    printf "\\033[1;91m  ===> error:\\033[0m expected file not found: %s\n" \
      "${expected}"
    exit 1
  fi
}

check_output() {
  cmd=$1
  expected=$2

  output=$(${cmd} | tee /dev/tty)
  if ! echo "${output}" | grep -q "${expected}"; then
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

ponyup_bin=build/release/ponyup
version=$(cut -f 1 <VERSION)

triple="$(cc -dumpmachine)"
echo "triple is ${triple}"
libc="${triple##*-}"
echo "libc is ${libc}"

query_url="https://api.cloudsmith.io/packages/ponylang/nightlies/"
query="?query=ponyc%20${libc}%20status:completed&page=1&page_size=3"
response=$(curl --request GET "${query_url}${query}")
recent_releases=$(echo "${response}" |
  sed 's/, /\n/g' |
  awk '/"version":/ {print $2}' |
  sed 's/"//g')

latest=$(echo "${recent_releases}" | head -1)
echo "latest = ${latest}"
previous=$(echo "${recent_releases}" | tail -1)
echo "previous = ${previous}"

prefix="./.pony_test"

rm -rf ${prefix}

test_title "version"
check_output "${ponyup_bin} version" "ponyup ${version}"

test_title "nightly"
${ponyup_bin} update nightly --verbose --prefix="${prefix}" --libc=${libc}
check_file "${prefix}/ponyup/nightly-${latest}/bin/ponyc"
check_file "${prefix}/ponyup/nightly-${latest}/bin/corral"
check_file "${prefix}/ponyup/nightly-${latest}/bin/stable"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${latest}"
check_output "${ponyup_bin} show -v -p=${prefix}" "nightly-${latest}"

test_title "up to date"
check_output \
  "${ponyup_bin} update -v -p=${prefix} --libc=${libc} nightly-${latest}" \
  "nightly-${latest}-${libc} is up to date"
check_file "${prefix}/ponyup/nightly-${latest}/bin/ponyc"
check_file "${prefix}/ponyup/nightly-${latest}/bin/corral"
check_file "${prefix}/ponyup/nightly-${latest}/bin/stable"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${latest}"
check_output "${ponyup_bin} show -v -p=${prefix}" "nightly-${latest}"

test_title "nightly (previous)"
${ponyup_bin} -v "-p=${prefix}" update "nightly-${previous}" "--libc=${libc}"
check_file "${prefix}/ponyup/nightly-${previous}/bin/ponyc"
check_file "${prefix}/ponyup/nightly-${previous}/bin/corral"
check_file "${prefix}/ponyup/nightly-${previous}/bin/stable"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${previous}"
check_output "${ponyup_bin} show -v -p=${prefix}" "nightly-${previous}"
