#!/bin/bash

# EXPERIMENTAL: build the x86-64-unknown-linux ponyup nightly and publish it to
# GHCR only (no Cloudsmith). Driven by experiment-ghcr-nightly.yml to validate
# the GHCR publishing pipeline in isolation, without touching the production
# nightly pipeline. Publishes under the throwaway `ponyup-experiment` package
# name. Delete this script and its workflow once GHCR publishing is validated
# and integrated into the real nightly scripts.
# See https://github.com/ponylang/ponyup/discussions/412.
#
# Tools required in the environment that runs this:
#
# - bash
# - corral
# - GNU make
# - gzip
# - ponyc (musl based version)
# - python3
# - tar

set -o errexit

# Pull in shared configuration specific to this repo
base=$(dirname "$0")
# shellcheck source=.ci-scripts/release/config.bash
source "${base}/config.bash"

# Verify ENV is set up correctly
if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo -e "\e[31mName of this repository needs to be set in GITHUB_REPOSITORY."
  echo -e "\e[31mShould be in the form OWNER/REPO, for example:"
  echo -e "\e[31m     ponylang/ponyup"
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo -e "\e[31mGITHUB_TOKEN needs to be set for GHCR publishing."
  echo -e "Exiting.\e[0m"
  exit 1
fi

if [[ -z "${APPLICATION_NAME}" ]]; then
  echo -e "\e[31mAPPLICATION_NAME needs to be set."
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

# no unset variables allowed from here on out
# allow above so we can display nice error messages for expected unset variables
set -o nounset

TODAY=$(date +%Y%m%d)

# Compiler target parameters
ARCH=x86-64

# Triple construction
VENDOR=unknown
OS=linux
TRIPLE=${ARCH}-${VENDOR}-${OS}

# Build parameters
BUILD_PREFIX=$(mktemp -d)
APPLICATION_VERSION="nightly-${TODAY}"
BUILD_DIR=${BUILD_PREFIX}/${APPLICATION_VERSION}

# Asset information
PACKAGE_DIR=$(mktemp -d)
PACKAGE=${APPLICATION_NAME}-${TRIPLE}
ASSET_FILE=${PACKAGE_DIR}/${PACKAGE}.tar.gz

# Build application installation
echo -e "\e[34mBuilding ${APPLICATION_NAME}...\e[0m"
make install prefix="${BUILD_DIR}" arch=${ARCH} \
  version="${APPLICATION_VERSION}" static=true linker=bfd

# Package it all up
echo -e "\e[34mCreating .tar.gz of ${APPLICATION_NAME}...\e[0m"
pushd "${BUILD_PREFIX}" || exit 1
tar -cvzf "${ASSET_FILE}" -- *
popd || exit 1

# Ship it off to GHCR as an OCI artifact (experimental package name)
echo -e "\e[34mUploading package to GHCR...\e[0m"
python3 "${base}/ghcr_nightly.py" push ponyup-experiment "${TRIPLE}" \
  "${TODAY}" "${ASSET_FILE}"
