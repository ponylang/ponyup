#!/bin/sh

set -o errexit
set -o nounset

default_prefix="$HOME/.pony/ponyup"

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

prefix=${default_prefix}
for arg in "$@"; do
  case "${arg}" in
  "--prefix="*)
    prefix=${arg##--prefix=}
    echo "${prefix}"
    ;;
  *)
    exit_usage
    ;;
  esac
done

mkdir -p "${prefix}/bin"

platform_os=$(uname -s)
if [ "$(echo "${platform_os}" | cut -c1-5)" != "Linux" ]; then
  echo "Unsupported OS: ${platform_os}"
  exit 1
fi

platform_cpu=$(uname -m)
case "${platform_cpu}" in
"x86_64" | "x86-64" | "x64" | "amd64")
  platform_cpu="x86-64"
  ;;
*)
  echo "Unsupported CPU type: ${platform_cpu}"
  exit 1
  ;;
esac

query_url="https://api.cloudsmith.io/packages/ponylang/nightlies/"
query="?query=ponyup-${platform_cpu}&page=1&page_size=1"

response=$(curl --request GET "${query_url}${query}")
if [ "${response}" = "[]" ]; then
  echo "failed to download ponyup"
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

dl_checksum="$(shasum "${tmp_dir}/${filename}" -a 256 | awk '{ print $1 }')"

if [ "${dl_checksum}" != "${checksum}" ]; then
  echo "checksum mismatch:"
  echo "    expected: ${checksum}"
  echo "  calculated: ${dl_checksum}"

  rm -f "${tmp_dir}/${filename}"
  exit 1
fi
echo "checksum ok"

tar -xzf "${tmp_dir}/${filename}" -C "${tmp_dir}"
mv "$(find ${tmp_dir} -name ponyup -type f)" "${prefix}/bin/ponyup"

echo "ponyup placed in ${prefix}/bin"

if ! echo "$PATH" | grep -q "${prefix}/bin"; then
  printf "\n%s\n\n  %s\n\n" \
    "I recommend adding ${prefix}/bin to \$PATH:" \
    "export PATH=${prefix}/bin:\$PATH"
fi
