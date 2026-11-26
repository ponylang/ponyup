#!/bin/sh

set -o errexit
set -o nounset

if [ -z "${XDG_DATA_HOME+x}" ]; then
  default_prefix="$HOME/.local/share"
else
  default_prefix="$XDG_DATA_HOME"
fi

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
"arm64" | "aarch64")
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
    *"Ubuntu 26.04"*)
      platform_triple_distro="ubuntu26.04"
      ;;
    *"Ubuntu 24.04"*)
      platform_triple_distro="ubuntu24.04"
      ;;
    *"Pop!_OS 24.04"*)
      platform_triple_distro="ubuntu24.04"
      ;;
    *) ;;
    esac
    ;;
  *musl)
    case "$(cat /etc/alpine-release)" in
    *3.24.*)
      platform_triple_distro="alpine3.24"
      ;;
    *3.23.*)
      platform_triple_distro="alpine3.23"
      ;;
    *)
      # default to generic musl- we don't have these for arm64 so they it will
      # fail to download
      platform_triple_distro="musl"
    ;;
    esac
    ;;
  *) ;;
  esac
  ;;
esac

if [ "${platform_triple_distro}" != "" ]; then
  platform_triple="${platform_triple}-${platform_triple_distro}"
fi

ponyup_root="${prefix}/ponyup"
echo "ponyup_root = ${ponyup_root}"

tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT
triple="${download_cpu}-${download_os}"
filename="ponyup-${triple}.tar.gz"
archive="${tmp_dir}/${filename}"
algorithm=512

case "${repository}" in
releases)
  releases=https://github.com/ponylang/ponyup/releases
  location=$(curl -fsS -o /dev/null -w '%{redirect_url}' "${releases}/latest")
  version=${location##*/}
  asset_url="${releases}/download/${version}/${filename}"
  status=$(curl -sSL -o "${tmp_dir}/checksum" -w '%{http_code}' "${asset_url}.sha512")
  if [ "${status}" = 200 ]; then
    status=$(curl -sSL -o "${archive}" -w '%{http_code}' "${asset_url}")
  fi
  case "${status}" in
  200) ;;
  404)
    version=$(python3 - "${filename}" <<'PYTHON'
import json
import os
import subprocess
import sys

asset = sys.argv[1]
curl = ["curl", "-fsS"]
headers = None
token = os.environ.get("GITHUB_TOKEN")
if token:
    curl += ["-H", "@-"]
    headers = f"Authorization: Bearer {token}\n".encode()
page = 1
while True:
    url = f"https://api.github.com/repos/ponylang/ponyup/releases?per_page=100&page={page}"
    releases = json.loads(subprocess.check_output(curl + [url], input=headers))
    for release in releases:
        if release["draft"] or release["prerelease"]:
            continue
        names = {a["name"] for a in release["assets"] if a["state"] == "uploaded"}
        if {asset, asset + ".sha512"} <= names:
            print(release["tag_name"])
            sys.exit(0)
    if len(releases) < 100:
        sys.exit(f"No release contains {asset} and its checksum")
    page += 1
PYTHON
)
    asset_url="${releases}/download/${version}/${filename}"
    curl -fsSL "${asset_url}.sha512" -o "${tmp_dir}/checksum"
    curl -fsSL "${asset_url}" -o "${archive}"
    ;;
  *) echo "Could not fetch ${filename} or its checksum (HTTP ${status})" >&2; exit 1 ;;
  esac
  checksum=$(cat "${tmp_dir}/checksum")
  channel=release
  ;;
nightlies)
  python3 - "${triple}" "${tmp_dir}" "${archive}" <<'PYTHON'
import json
import pathlib
import re
import subprocess
import sys

triple, directory, archive = sys.argv[1:]
tmp = pathlib.Path(directory)
repo = "ponylang/nightly/ponyup-" + triple
base = "https://ghcr.io/v2/" + repo
token_url = f"https://ghcr.io/token?service=ghcr.io&scope=repository:{repo}:pull"
curl = ["curl", "-fsSL"]
token = json.loads(subprocess.check_output(curl + [token_url]))["token"]
auth = tmp / "authorization"
auth.write_text("Authorization: Bearer " + token)
curl += ["-H", "@" + str(auth)]

version = ""
url = base + "/tags/list?n=100"
while url:
    headers = tmp / "headers"
    page = json.loads(subprocess.check_output(curl + ["-D", str(headers), url]))
    versions = (tag for tag in page["tags"] if re.fullmatch(r"[0-9]{8}", tag))
    version = max(version, max(versions, default=""))
    link = re.search(r'^link:\s*<([^>]+)>;\s*rel="next"', headers.read_text(), re.I | re.M)
    url = ""
    if link:
        path = link[1]
        if not path.startswith(f"/v2/{repo}/tags/list?"):
            sys.exit("Unexpected GHCR pagination URL")
        url = "https://ghcr.io" + path
if not version:
    sys.exit(f"No nightly tags for {repo}")

manifest = json.loads(subprocess.check_output(curl + [
    "-H", "Accept: application/vnd.oci.image.manifest.v1+json",
    f"{base}/manifests/{version}"]))
if manifest["artifactType"] != "application/vnd.ponylang.nightly.v1":
    sys.exit("Unexpected nightly artifact type")
layer, = manifest["layers"]
if layer["annotations"]["org.opencontainers.image.title"] != f"ponyup-{triple}.tar.gz":
    sys.exit("Unexpected archive in nightly manifest")
digest = layer["digest"]
if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
    sys.exit("Invalid archive digest in nightly manifest")
(tmp / "version").write_text(version)
(tmp / "checksum").write_text(digest.split(":")[1])
subprocess.run(curl + [f"{base}/blobs/{digest}", "-o", archive], check=True)
PYTHON
  version=$(cat "${tmp_dir}/version")
  checksum=$(cat "${tmp_dir}/checksum")
  algorithm=256
  channel=nightly
  ;;
*)
  query_url="https://api.cloudsmith.io/packages/ponylang/${repository}/"
  response=$(curl -fsSL "${query_url}?query=ponyup-${triple}&page=1&page_size=1")
  if [ "${response}" = "[]" ]; then
    echo "Failed to find ponyup in ${repository}" >&2
    exit 1
  fi
  version=$(json_field "${response}" version)
  checksum=$(json_field "${response}" checksum_sha256)
  curl -fsSL "$(json_field "${response}" cdn_url)" -o "${archive}"
  algorithm=256
  channel=nightly
  ;;
esac

if command -v "sha${algorithm}sum" > /dev/null 2>&1; then
  digest=$("sha${algorithm}sum" "${archive}")
else
  digest=$(shasum -a "${algorithm}" "${archive}")
fi
dl_checksum=${digest%% *}

if [ "${dl_checksum}" != "${checksum}" ]; then
  printf "%bchecksum mismatch:\n" "${RED}"
  printf "    expected: %b%s%b\n" "${BLUE}" "${checksum}" "${RED}"
  printf "  calculated: %b%s%b\n" "${YELLOW}" "${dl_checksum}" "${DEFAULT}"
  exit 1
fi
echo "checksum ok"

case "${version}" in
  ''|*[!a-zA-Z0-9._-]*) echo "Invalid ponyup version" >&2; exit 1 ;;
esac
ponyup_pkg="ponyup-${channel}-${version}-${platform_triple_cpu}-${download_os##*-}"
version_bin="${ponyup_root}/${ponyup_pkg}/bin"
mkdir -p "${version_bin}" "${ponyup_root}/bin"
tar -xzf "${archive}" -C "${tmp_dir}"
mv "$(find "${tmp_dir}" -name ponyup -type f)" "${version_bin}/ponyup"
ln -sf "../${ponyup_pkg}/bin/ponyup" "${ponyup_root}/bin/ponyup"
echo "${platform_triple}" > "${ponyup_root}/.platform"
if [ -f "${ponyup_root}/.lock" ]; then
  while IFS= read -r entry || [ -n "${entry}" ]; do
    case "${entry}" in
      '') continue ;;
      ponyup-*)
        pkg=${entry%% *}
        if [ "${pkg}" != "${ponyup_pkg}" ] && [ -d "${ponyup_root}/${pkg}" ]; then
          printf '%s\n' "${pkg}"
        fi
        ;;
      *) printf '%s\n' "${entry}" ;;
    esac
  done < "${ponyup_root}/.lock" > "${tmp_dir}/lock"
fi
printf '%s *\n' "${ponyup_pkg}" >> "${tmp_dir}/lock"
mv "${tmp_dir}/lock" "${ponyup_root}/.lock"

printf "%bponyup placed in %b${ponyup_root}/bin%b\n" \
  "${BLUE}" "${YELLOW}" "${DEFAULT}"

if ! echo "$PATH" | grep -q "${ponyup_root}/bin"; then
  case "${SHELL:-}" in
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

    exit 0
  fi
esac

printf "%bsetting default platform to %b${platform_triple}%b\n" \
  "${BLUE}" "${YELLOW}" "${DEFAULT}"

"${ponyup_root}/bin/ponyup" --prefix="${prefix}" default "${platform_triple}"
