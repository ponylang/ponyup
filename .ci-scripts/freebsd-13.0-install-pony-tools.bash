#!/bin/bash

#
# Install ponyc the hard way
# It will end up in /tmp/ponyc/ with the binary at /tmp/ponyc/bin/ponyc
#

cd /tmp || exit 1
mkdir ponyc
curl -O 'https://dl.cloudsmith.io/public/ponylang/releases/raw/versions/latest/ponyc-x86-64-unknown-freebsd-13.0.tar.gz'
tar -xvf ponyc-x86-64-unknown-freebsd-13.0.tar.gz -C ponyc --strip-components=1

#
# Install corral the hard way
# It will end up in /tmp/corral/ with the binary at /tmp/corral/bin/corral
#

cd /tmp || exit 1
mkdir corral
curl -O 'https://dl.cloudsmith.io/public/ponylang/releases/raw/versions/latest/corral-x86-64-unknown-freebsd-13.0.tar.gz'
tar -xvf corral-x86-64-unknown-freebsd-13.0.tar.gz -C corral --strip-components=1
