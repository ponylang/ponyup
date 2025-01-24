#!/bin/bash

case "${1}" in
"release")
  REPO=releases
  ;;
"nightly")
  REPO=nightlies
  ;;
*)
  echo "invalid ponyc version"
  echo "Options:"
  echo "release"
  echo "nightly"
  exit 1
esac

#
# Libresll is required for ponyup
#

brew update
brew install libressl

pushd /tmp || exit
mkdir ponyc
echo ""https://dl.cloudsmith.io/public/ponylang/${REPO}/raw/versions/latest/ponyc-arm64-apple-darwin.tar.gz""
wget "https://dl.cloudsmith.io/public/ponylang/${REPO}/raw/versions/latest/ponyc-arm64-apple-darwin.tar.gz" -O ponyc.tar.gz
tar xzf ponyc.tar.gz -C ponyc --strip-components=1
popd || exit

pushd /tmp || exit
mkdir corral
wget "https://dl.cloudsmith.io/public/ponylang/${REPO}/raw/versions/latest/corral-arm64-apple-darwin.tar.gz" -O corral.tar.gz
tar xzf corral.tar.gz -C corral --strip-components=1
popd || exit
