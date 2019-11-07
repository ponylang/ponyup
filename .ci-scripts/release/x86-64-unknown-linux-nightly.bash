#!/bin/bash

set -e

API_KEY=$1
if [[ ${API_KEY} == "" ]]; then
  echo "API_KEY needs to be supplied as first script argument."
  exit 1
fi

TODAY=$(date +%Y%m%d)

# Compiler target parameters
ARCH=x86-64

# Triple construction
VENDOR=unknown
OS=linux
TRIPLE=${ARCH}-${VENDOR}-${OS}

# Build parameters
BUILD_PREFIX=$(mktemp -d)
PONYUP_VERSION="nightly-${TODAY}"
BUILD_DIR=${BUILD_PREFIX}/${PONYUP_VERSION}

# Asset information
PACKAGE_DIR=$(mktemp -d)
PACKAGE=ponyup-${TRIPLE}

# Cloudsmith configuration
CLOUDSMITH_VERSION=${TODAY}
ASSET_OWNER=ponylang
ASSET_REPO=nightlies
ASSET_PATH=${ASSET_OWNER}/${ASSET_REPO}
ASSET_FILE=${PACKAGE_DIR}/${PACKAGE}.tar.gz
ASSET_SUMMARY="The Pony toolchain multiplexer"
ASSET_DESCRIPTION="https://github.com/ponylang/ponyup"

# Build ponyup installation
echo "Building ponyup..."
make install prefix="${BUILD_DIR}" arch=${ARCH} version="${PONYUP_VERSION}" \
  ssl=0.9.0 static=true linker=bfd

# Package it all up
echo "Creating .tar.gz of ponyup..."
pushd "${BUILD_PREFIX}" || exit 1
tar -cvzf "${ASSET_FILE}" *
popd || exit 1

# Ship it off to cloudsmith
echo "Uploading package to cloudsmith..."
cloudsmith push raw --version "${CLOUDSMITH_VERSION}" --api-key "${API_KEY}" \
  --summary "${ASSET_SUMMARY}" --description "${ASSET_DESCRIPTION}" \
  ${ASSET_PATH} "${ASSET_FILE}"
