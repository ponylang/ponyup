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

  output=$(${cmd} | tee "$(tty)")
  rm -f 'not a tty'
  if ! echo "${output}" | grep -q "${expected}"; then
    printf "\\033[1;91m  ===> error:\\033[0m did not match \"%s\"\n" \
      "${expected}"
    exit 1
  fi
}

test_title() {
  title=$1
  printf "\\033[1;32m========================================================\n"
  printf "  Test: %s\n" "${title}"
  printf "========================================================\\033[0m\n"
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

ponyup_package() {
  package_name=$1
  channel=$2
  version=$3
  libc=$4
  package="${package_name}-${channel}-${version}"
  if [ "${package_name}" = "ponyc" ]; then package="${package}-${libc}"; fi
  echo "${package}"
}

ponyup_bin=build/release/ponyup
version=$(cut -f 1 <VERSION)

triple="$(cc -dumpmachine)"
echo "triple is ${triple}"
libc="${triple##*-}"
echo "libc is ${libc}"

# Packages with release versions are placed at the front of this list.
# Otherwise, the packages are listed in alphabetical order.
packages="ponyc changelog-tool corral stable"

ponyc_versions=$(latest_versions nightlies ponyc)
latest_versions="$(echo "${ponyc_versions}" | head -1)"
prev_versions="$(echo "${ponyc_versions}" | tail -1)"
release_versions="$(latest_versions releases ponyc 1)"
latest_ponyc="$latest_versions"

changelog_tool_versions=$(latest_versions nightlies changelog-tool)
latest_versions="${latest_versions} $(echo "${changelog_tool_versions}" | head -1)"
prev_versions="${prev_versions} $(echo "${changelog_tool_versions}" | tail -1)"

corral_versions=$(latest_versions nightlies corral)
latest_versions="${latest_versions} $(echo "${corral_versions}" | head -1)"
prev_versions="${prev_versions} $(echo "${corral_versions}" | tail -1)"

stable_versions=$(latest_versions nightlies stable)
latest_versions="${latest_versions} $(echo "${stable_versions}" | head -1)"
prev_versions="${prev_versions} $(echo "${stable_versions}" | tail -1)"

for i in $(seq 1 "$(echo "${packages}" | wc -w)"); do
  package=$(echo "${packages}" | awk "{print \$${i}}")
  latest=$(echo "${latest_versions}" | awk "{print \$${i}}")
  prev=$(echo "${prev_versions}" | awk "{print \$${i}}")
  release=$(echo "${release_versions}" | awk "{print \$${i}}")
  echo "${package}: latest=${latest} previous=${prev} release=${release}"
done

prefix="./.pony_test"
rm -rf ${prefix}

test_title "version"
check_output "${ponyup_bin} version" "ponyup ${version}"

test_title "unknown package"
check_output "${ponyup_bin} update foo nightly" "unknown package: foo"

for i in $(seq 1 "$(echo "${packages}" | wc -w)"); do
  package=$(echo "${packages}" | awk "{print \$${i}}")
  version=$(echo "${latest_versions}" | awk "{print \$${i}}")
  test_title "update ${package} nightly"
  ${ponyup_bin} update "${package}" nightly \
    --verbose --prefix="${prefix}" "--libc=${libc}"
  pkg_name=$(ponyup_package "${package}" nightly "${version}" "${libc}")
  check_file "${prefix}/ponyup/${pkg_name}/bin/${package}"

  if [ "${package}" = "ponyc" ]; then
    check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${version}"
  fi
done

for i in $(seq 1 "$(echo "${release_versions}" | wc -w)"); do
  package=$(echo "${packages}" | awk "{print \$${i}}")
  version=$(echo "${release_versions}" | awk "{print \$${i}}")
  test_title "update ${package} release"
  ${ponyup_bin} update ponyc release -v "-p=${prefix}" "--libc=${libc}"
  pkg_name=$(ponyup_package "${package}" release "${version}" "${libc}")
  check_file "${prefix}/ponyup/${pkg_name}/bin/${package}"
done

test_title "switch up-to-date version"
check_output \
  "${ponyup_bin} update -v -p=${prefix} --libc=${libc} \
    ponyc nightly-${latest_ponyc}" \
  "ponyc-nightly-${latest_ponyc}-${libc} is up to date"
check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${latest_ponyc}"

for i in $(seq 1 "$(echo "${packages}" | wc -w)"); do
  package=$(echo "${packages}" | awk "{print \$${i}}")
  version=$(echo "${prev_versions}" | awk "{print \$${i}}")
  test_title "update ${package} nightly-${version}"
  ${ponyup_bin} update "${package}" "nightly-${version}" \
    -v "-p=${prefix}" "--libc=${libc}"

  pkg_name=$(ponyup_package "${package}" nightly "${version}" "${libc}")
  check_file "${prefix}/ponyup/${pkg_name}/bin/${package}"
done

for i in $(seq 1 "$(echo "${packages}" | wc -w)"); do
  package=$(echo "${packages}" | awk "{print \$${i}}")
  version0=$(echo "${latest_versions}" | awk "{print \$${i}}")
  version1=$(echo "${prev_versions}" | awk "{print \$${i}}")
  test_title "select ${package} nightly-${version1}"

  if [ "${package}" = "ponyc" ]; then
    check_output "${prefix}/ponyup/bin/ponyc --version" "nightly-${version0}"
  else
    check_output "${prefix}/ponyup/bin/${package} ver" "nightly-${version0}"
  fi
done
