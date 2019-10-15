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

latest_versions() {
  package=$1
  query_url="https://api.cloudsmith.io/packages/ponylang/nightlies/"
  query="?query=${package}"
  if [ "${package}" = "ponyc" ]; then query="${query}%20${libc}"; fi
  query="${query}%20status:completed&page=1&page_size=2"
  response=$(curl --request GET "${query_url}${query}")
  echo "${response}" |
    sed 's/, /\n/g' |
    awk '/"version":/ {print $2}' |
    sed 's/"//g'
}

ponyup_bin=build/release/ponyup
version=$(cut -f 1 <VERSION)

triple="$(cc -dumpmachine)"
echo "triple is ${triple}"
libc="${triple##*-}"
echo "libc is ${libc}"

ponyup_versions=$(latest_versions ponyup)
latest_ponyup=$(echo "${ponyup_versions}" | head -1)
previous_ponyup=$(echo "${ponyup_versions}" | tail -1)
echo "ponyup versions: ${latest_ponyup} ${previous_ponyup}"

ponyc_versions=$(latest_versions ponyc)
latest_ponyc=$(echo "${ponyc_versions}" | head -1)
previous_ponyc=$(echo "${ponyc_versions}" | tail -1)
echo "ponyc versions: ${latest_ponyc} ${previous_ponyc}"

corral_versions=$(latest_versions corral)
latest_corral=$(echo "${corral_versions}" | head -1)
previous_corral=$(echo "${corral_versions}" | tail -1)
echo "corral versions: ${latest_corral} ${previous_corral}"

stable_versions=$(latest_versions stable)
latest_stable=$(echo "${stable_versions}" | head -1)
previous_stable=$(echo "${stable_versions}" | tail -1)
echo "stable versions: ${latest_stable} ${previous_stable}"

prefix="./.pony_test"

rm -rf ${prefix}

test_title "version"
check_output "${ponyup_bin} version" "ponyup ${version}"

test_title "nightly"
${ponyup_bin} update nightly --verbose --prefix="${prefix}" --libc=${libc}
check_file "${prefix}/ponyup/nightly-${latest_ponyc}/bin/ponyc"
check_file "${prefix}/ponyup/nightly-${latest_corral}/bin/corral"
check_file "${prefix}/ponyup/nightly-${latest_stable}/bin/stable"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${latest_ponyc}"
check_output "${ponyup_bin} show -v -p=${prefix}" "nightly-${latest_ponyup}"

test_title "up to date"
check_output \
  "${ponyup_bin} update -v -p=${prefix} --libc=${libc} nightly-${latest_ponyc}" \
  "nightly-${latest_ponyc}-${libc} is up to date"
check_file "${prefix}/ponyup/nightly-${latest_ponyc}/bin/ponyc"
check_file "${prefix}/ponyup/nightly-${latest_corral}/bin/corral"
check_file "${prefix}/ponyup/nightly-${latest_stable}/bin/stable"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${latest_ponyc}"
check_output "${ponyup_bin} show -v -p=${prefix}" "nightly-${latest_ponyup}"

test_title "nightly (previous)"
${ponyup_bin} -v "-p=${prefix}" update "nightly-${previous_ponyc}" "--libc=${libc}"
check_file "${prefix}/ponyup/nightly-${previous_ponyc}/bin/ponyc"
check_file "${prefix}/ponyup/nightly-${previous_corral}/bin/corral"
check_file "${prefix}/ponyup/nightly-${previous_stable}/bin/stable"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${previous_ponyc}"
check_output "${ponyup_bin} show -v -p=${prefix}" "nightly-${previous_ponyup}"
