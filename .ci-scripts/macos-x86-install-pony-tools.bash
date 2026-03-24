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
# Install ponyc the hard way
# It will end up in /tmp/ponyc/ with the binary at /tmp/ponyc/bin/ponyc
#

pushd /tmp || exit
mkdir ponyc
wget "https://dl.cloudsmith.io/public/ponylang/${REPO}/raw/versions/latest/ponyc-x86-64-apple-darwin.tar.gz" -O ponyc.tar.gz
tar xzf ponyc.tar.gz -C ponyc --strip-components=1
popd || exit

#
# Install corral the hard way
# It will end up in /tmp/corral/ with the binary at /tmp/corral/bin/corral
#

pushd /tmp || exit
mkdir corral
wget "https://dl.cloudsmith.io/public/ponylang/${REPO}/raw/versions/latest/corral-x86-64-apple-darwin.tar.gz" -O corral.tar.gz
tar xzf corral.tar.gz -C corral --strip-components=1
popd || exit
