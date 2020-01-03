#!/bin/sh

set -o errexit
set -o nounset

default_prefix="$HOME/.local/share"
default_repository="releases"

exit_usage() {
  printf "%s\n\n" "ponyup-init.sh"
  echo "Options:"
  echo "  --prefix      Set ponyup install prefix. Default: ${default_prefix}"
  exit 1
}

json_field() {
  json=$1
  key=$2
  echo "${json}" |
    awk -F"\"${key}\":" '{print $2}' |
    awk '{print $1}' |
    sed 's/[",]//g'
}

DEFAULT="\e[39m"
BLUE="\e[34m"
RED="\e[31m"
YELLOW="\e[33m"

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
*)
  printf "%bUnsupported CPU type: ${uname_m}%b\n" "${RED}" "${DEFAULT}"
  exit 1
  ;;
esac

uname_s=$(uname -s)
case "${uname_s}" in
Linux*)
  download_os="unknown-linux"
  platform_triple_os="unknown-linux"
  ;;
Darwin*)
  download_os="apple-darwin"
  platform_triple_os="apple-darwin"
  ;;
*)
  printf "%bUnsupported OS: ${uname_s}%b\n" "${RED}" "${DEFAULT}"
  exit 1
  ;;
esac

platform_triple="${platform_triple_cpu}-${platform_triple_os}"
case "${uname_s}" in
Linux*)
  case $(cc -dumpmachine) in
    *gnu)
      platform_triple="${platform_triple}-gnu"
      ;;
    *musl)
      platform_triple="${platform_triple}-musl"
      ;;
    *)
      printf "%bUnable to determine libc type.\n" "${BLUE}"
      printf "If you are using a musl libc based Linux, you'll need to use\n"
      printf "%b--platform=musl%b when installing ponyc.%b\n" \
        "${YELLOW}" "$BLUE}" "${DEFAULT}"
      ;;
  esac
  ;;
esac

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

checksum=$(json_field "${response}" checksum_sha256)
dl_url=$(json_field "${response}" cdn_url)

echo "checksum=${checksum}"
echo "dl_url=${dl_url}"

filename="$(basename "${dl_url}")"
tmp_dir=/tmp/ponyup
mkdir -p "${tmp_dir}"
echo "downloading ${filename}"

curl "${dl_url}" -o "${tmp_dir}/${filename}"

dl_checksum="$(sha256sum "${tmp_dir}/${filename}" | awk '{ print $1 }')"

if [ "${dl_checksum}" != "${checksum}" ]; then
  printf "%bmchecksum mismatch:\n" "${RED}"
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
  printf "%bYou should add %b${ponyup_root}/bin%b to \$PATH:%b\n" \
    "${BLUE}" "${YELLOW}" "${BLUE}" "${DEFAULT}"
  printf "%bexport PATH=${ponyup_root}/bin:\$PATH%b\n" \
    "${YELLOW}" "${DEFAULT}"
fi
