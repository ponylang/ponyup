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

  output=$(${cmd} | tee $(tty))
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
  repo=$1
  package=$2
  count=${3:-2}
  query_url="https://api.cloudsmith.io/packages/ponylang/${repo}/"
  query="?query=${package}"
  if [ "${package}" = "ponyc" ]; then query="${query}%20${libc}"; fi
  query="${query}%20status:completed&page=1&page_size=${count}"
  response=$(curl -s --request GET "${query_url}${query}")
  echo "${response}" |
    sed 's/, /\n/g' |
    awk '/"version":/ {print $2}' |
    sed 's/"//g'
}

ponyup_bin=build/release/ponyup
packages="ponyc stable corral"
version=$(cut -f 1 <VERSION)

triple="$(cc -dumpmachine)"
echo "triple is ${triple}"
libc="${triple##*-}"
echo "libc is ${libc}"

ponyup_versions=$(latest_versions nightlies ponyup)
latest_ponyup=$(echo "${ponyup_versions}" | head -1)
prev_ponyup=$(echo "${ponyup_versions}" | tail -1)
echo "ponyup versions: ${latest_ponyup} ${prev_ponyup}"

ponyc_versions=$(latest_versions nightlies ponyc)
latest_ponyc=$(echo "${ponyc_versions}" | head -1)
prev_ponyc=$(echo "${ponyc_versions}" | tail -1)
release_ponyc=$(latest_versions releases ponyc 1)
echo "ponyc  versions: ${latest_ponyc} ${prev_ponyc} ${release_ponyc}"

corral_versions=$(latest_versions nightlies corral)
latest_corral=$(echo "${corral_versions}" | head -1)
prev_corral=$(echo "${corral_versions}" | tail -1)
echo "corral versions: ${latest_corral} ${prev_corral}"

stable_versions=$(latest_versions nightlies stable)
latest_stable=$(echo "${stable_versions}" | head -1)
prev_stable=$(echo "${stable_versions}" | tail -1)
echo "stable versions: ${latest_stable} ${prev_stable}"

prefix="./.pony_test"

rm -rf ${prefix}

test_title "version"
check_output "${ponyup_bin} version" "ponyup ${version}"

for package in ${packages}; do
  test_title "update ${package} nightly"
  ${ponyup_bin} update "${package}" nightly \
    --verbose --prefix="${prefix}" "--libc=${libc}"
  check_file "${prefix}/ponyup/nightly-${latest_ponyc}/bin/${package}"

  if [ "${package}" = "ponyc" ]; then
    check_output \
      "${prefix}/ponyup/bin/ponyc --version" \
      "nightly-${latest_ponyc}"
  fi
done

test_title "update ponyc release"
${ponyup_bin} update ponyc release -v "-p=${prefix}" "--libc=${libc}"
check_file "${prefix}/ponyup/release-${release_ponyc}/bin/ponyc"
check_output "${prefix}/ponyup/bin/ponyc --version" "${release_ponyc}"

test_title "switch up-to-date version"
check_output \
  "${ponyup_bin} update -v -p=${prefix} --libc=${libc} \
    ponyc nightly-${latest_ponyc}" \
  "nightly-${latest_ponyc}-${libc} is up to date"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${latest_ponyc}"

prev_versions="${prev_ponyc} ${prev_stable} ${prev_corral}"
for i in $(seq 1 "$(echo "${packages}" | wc -w)"); do
  package=$(echo "${packages}" | cut -d ' ' -f "${i}")
  version=$(echo "${prev_versions}" | cut -d ' ' -f "${i}")
  test_title "update ${package} nightly-${version}"
  ${ponyup_bin} update "${package}" "nightly-${version}" \
    -v "-p=${prefix}" "--libc=${libc}"
  check_file "${prefix}/ponyup/nightly-${version}/bin/${package}"

  if [ "${package}" = "ponyc" ]; then
    check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${version}"
  fi
done
