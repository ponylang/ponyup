#!/bin/bash

#
# Builds LibreSSL from source for the current macOS architecture and places
# the static libraries in the repo's lib/darwin-* directory.
#
# This script is called by the "Update vendored LibreSSL" workflow. It runs
# on macOS CI runners (the same ones used for release builds) so that the
# compiled code targets the same generic CPUs as nightlies and releases.
#
# Environment:
#   LIBRESSL_VERSION  LibreSSL version to build (default: 4.2.1)
#

set -o errexit
set -o nounset

LIBRESSL_VERSION="${LIBRESSL_VERSION:-4.2.1}"

# Determine architecture and map to directory name
UNAME_M=$(uname -m)
case "${UNAME_M}" in
arm64)
  LIB_DIR="lib/darwin-arm64"
  CMAKE_ARCH="arm64"
  ;;
x86_64)
  LIB_DIR="lib/darwin-x86-64"
  CMAKE_ARCH="x86_64"
  ;;
*)
  echo "Unsupported architecture: ${UNAME_M}"
  exit 1
  ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARBALL="libressl-${LIBRESSL_VERSION}.tar.gz"
URL="https://github.com/libressl/portable/releases/download/v${LIBRESSL_VERSION}/${TARBALL}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Downloading LibreSSL ${LIBRESSL_VERSION}..."
curl -fsSL "${URL}" -o "${WORK_DIR}/${TARBALL}"

echo "Extracting..."
tar xzf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"

SRC_DIR="${WORK_DIR}/libressl-${LIBRESSL_VERSION}"
BUILD_DIR="${WORK_DIR}/build"

echo "Building static libraries for ${CMAKE_ARCH}..."
cmake -B "${BUILD_DIR}" -S "${SRC_DIR}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DLIBRESSL_APPS=OFF \
  -DLIBRESSL_TESTS=OFF \
  -DCMAKE_OSX_ARCHITECTURES="${CMAKE_ARCH}"

cmake --build "${BUILD_DIR}" --parallel

echo "Copying static libraries to ${LIB_DIR}..."
mkdir -p "${REPO_ROOT}/${LIB_DIR}"
cp "${BUILD_DIR}/ssl/libssl.a" "${REPO_ROOT}/${LIB_DIR}/"
cp "${BUILD_DIR}/crypto/libcrypto.a" "${REPO_ROOT}/${LIB_DIR}/"
cp "${BUILD_DIR}/tls/libtls.a" "${REPO_ROOT}/${LIB_DIR}/"

echo "Done. Static libraries for ${CMAKE_ARCH}:"
ls -la "${REPO_ROOT}/${LIB_DIR}/"
