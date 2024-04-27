#!/bin/sh

set -o errexit
set -o nounset

if [ -z "${XDG_DATA_HOME+x}" ]; then
  default_prefix="$HOME/.local/share"
else
  default_prefix="$XDG_DATA_HOME"
fi

default_repository="releases"

if [ "$(uname -s)" = "Darwin" ]; then
  # we have to use nightly releases on macOS
  # see https://github.com/ponylang/ponyup/issues/117
  default_repository="nightlies"
fi

exit_usage() {
  printf "%s\n\n" "ponyup-init.sh"
  echo "Options:"
  echo "  --prefix      Set ponyup install prefix. Default: ${default_prefix}"
  exit 1
}

json_field() {
  json=$1
  key=$2
  value_pattern=': *"\([^"]*\)"'
  echo "${json}" | sed "s/.*\"${key}\"${value_pattern}.*/\\1/"
}

DEFAULT="\033[39m"
BLUE="\033[34m"
RED="\033[31m"
YELLOW="\033[33m"

prefix="${default_prefix}"
repository="${default_repository}"
for arg in "$@"; do
  case "${arg}" in
  "--prefix="*)
    prefix=${arg##--prefix=}
    ;;
  "--repository="*)
    repository=${arg##--repository=}
    ;;
  *)
    exit_usage
    ;;
  esac
done

uname_m=$(uname -m)
case "${uname_m}" in
"x86_64" | "x86-64" | "x64" | "amd64")
  download_cpu="x86-64"
  platform_triple_cpu="x86_64"
  ;;
"arm64")
  download_cpu="arm64"
  platform_triple_cpu="arm64"
  ;;
*)
  printf "%bUnsupported CPU type: ${uname_m}%b\n" "${RED}" "${DEFAULT}"
  exit 1
  ;;
esac

uname_s=$(uname -s)
case "${uname_s}" in
Darwin*)
  download_os="apple-darwin"
  platform_triple_os="apple-darwin"
  ;;
Linux*)
  download_os="unknown-linux"
  platform_triple_os="unknown-linux"
  ;;
*)
  printf "%bUnsupported OS: ${uname_s}%b\n" "${RED}" "${DEFAULT}"
  exit 1
  ;;
esac

platform_triple="${platform_triple_cpu}-${platform_triple_os}"

platform_triple_distro=""
case "${uname_s}" in
Linux*)
  case $(cc -dumpmachine) in
  *gnu)
    case "$(lsb_release -d)" in
    *"Ubuntu 24.04"*)
      platform_triple_distro="ubuntu24.04"
      ;;
    *"Ubuntu 22.04"*)
      platform_triple_distro="ubuntu22.04"
      ;;
    *"Ubuntu 20.04"*)
      platform_triple_distro="ubuntu20.04"
      ;;
    *"Linux Mint 21"*)
      platform_triple_distro="ubuntu22.04"
      ;;
    *"Linux Mint 20"*)
      platform_triple_distro="ubuntu20.04"
      ;;
    *"Pop!_OS 24.04"*)
      platform_triple_distro="ubuntu24.04"
      ;;
    *"Pop!_OS 22.04"*)
      platform_triple_distro="ubuntu22.04"
      ;;
    *"Pop!_OS 20.04"*)
      platform_triple_distro="ubuntu20.04"
      ;;
    *) ;;
    esac
    ;;
  *x86_64-redhat-linux)
    case "$(lsb_release -d)" in
    *"Fedora Linux 39"*)
      platform_triple_distro="fedora39"
      ;;
    *) ;;
    esac
    ;;
  *musl)
    platform_triple_distro="musl"
    ;;
  *) ;;
  esac
  ;;
esac

if [ "${platform_triple_distro}" != "" ]; then
  platform_triple="${platform_triple}-${platform_triple_distro}"
fi

if command -v sha256sum > /dev/null 2>&1; then
  sha256sum='sha256sum'
elif command -v shasum > /dev/null 2>&1; then
  sha256sum='shasum --algorithm 256'
else
  printf "%bNo checksum command found.%b\n" "${RED}" "${DEFAULT}"
  exit 1
fi

ponyup_root="${prefix}/ponyup"
echo "ponyup_root = ${ponyup_root}"

mkdir -p "${ponyup_root}/bin"
echo "${platform_triple}" > "${ponyup_root}/.platform"

query_url="https://api.cloudsmith.io/packages/ponylang/${repository}/"
query="?query=ponyup-${download_cpu}-${download_os}&page=1&page_size=1"

response=$(curl --request GET "${query_url}${query}")
if [ "${response}" = "[]" ]; then
  printf "%bfailed to download ponyup%b\n" "${RED}" "${DEFAULT}"
  exit 1
fi

ponyup_pkg="$(json_field "${response}" version)"
ponyup_pkg="${ponyup_pkg}-${platform_triple_cpu}-${download_os##*-}"

if [ "${repository}" = releases ]; then
  ponyup_pkg="ponyup-release-${ponyup_pkg}"
else
  ponyup_pkg="ponyup-nightly-${ponyup_pkg}"
fi
echo "${ponyup_pkg}" > "${ponyup_root}/.lock"

checksum=$(json_field "${response}" checksum_sha256)
dl_url=$(json_field "${response}" cdn_url)

echo "checksum=${checksum}"
echo "dl_url=${dl_url}"

filename="$(basename "${dl_url}")"
tmp_dir=/tmp/ponyup
mkdir -p "${tmp_dir}"
echo "downloading ${filename}"

curl "${dl_url}" -o "${tmp_dir}/${filename}"

dl_checksum="$(${sha256sum} "${tmp_dir}/${filename}" | awk '{ print $1 }')"

if [ "${dl_checksum}" != "${checksum}" ]; then
  printf "%bchecksum mismatch:\n" "${RED}"
  printf "    expected: %b${checksum}%b\n" "${BLUE}" "${RED}"
  printf "  calculated: %b${dl_checksum}%b\n" "${YELLOW}" "${DEFAULT}"

  rm -f "${tmp_dir}/${filename}"
  exit 1
fi
echo "checksum ok"

tar -xzf "${tmp_dir}/${filename}" -C "${tmp_dir}"
mv "$(find ${tmp_dir} -name ponyup -type f)" "${ponyup_root}/bin/ponyup"

printf "%bponyup placed in %b${ponyup_root}/bin%b\n" \
  "${BLUE}" "${YELLOW}" "${DEFAULT}"

if ! echo "$PATH" | grep -q "${ponyup_root}/bin"; then
  case "${SHELL}" in
  *fish)
    printf "%bYou should add %b${ponyup_root}/bin%b to \$PATH:%b\n" \
      "${BLUE}" "${YELLOW}" "${BLUE}" "${DEFAULT}"
    printf "%bset -g fish_user_paths ${ponyup_root}/bin \$fish_user_paths%b\n" \
      "${YELLOW}" "${DEFAULT}"
    ;;
  *)
    printf "%bYou should add %b${ponyup_root}/bin%b to \$PATH:%b\n" \
      "${BLUE}" "${YELLOW}" "${BLUE}" "${DEFAULT}"
    printf "%bexport PATH=${ponyup_root}/bin:\$PATH%b\n" \
      "${YELLOW}" "${DEFAULT}"
    ;;
  esac
fi

case "${uname_s}" in
Linux*)
  if [ "${platform_triple_distro}" = "" ]; then
    printf "%bUnable to determine Linux platform type.%b\n" "${YELLOW}" "${DEFAULT}"
    printf "%bPlease see https://github.com/ponylang/ponyc/blob/main/INSTALL.md#linux to manually set your platform.%b\n" "${YELLOW}" "${DEFAULT}"

    # set prefix even if we don't know the default platform to set
    "${ponyup_root}/bin/ponyup" --prefix="${prefix}"

    # we don't consider this exit to be an error
    exit 0
  fi
esac

printf "%bsetting default platform to %b${platform_triple}%b\n" \
  "${BLUE}" "${YELLOW}" "${DEFAULT}"

"${ponyup_root}/bin/ponyup" --prefix="${prefix}" default "${platform_triple}"
