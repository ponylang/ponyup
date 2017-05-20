#!/bin/sh

set -o errexit
set -o nounset

apt-get update
apt-get install -y \
  build-essential \
  lsb-release \
  wget \
  git \
  zlib1g-dev \
  libncurses5-dev \
  libssl-dev \
  libpcre2-dev

cd /tmp
# TODO check for previous llvm install
wget "http://releases.llvm.org/3.9.1/clang+llvm-3.9.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz"
tar -xvf clang+llvm*
cd clang+llvm* && sudo cp -R ./* /usr/local && cd -
cd /usr/local

git clone https://github.com/ponylang/ponyc
cd ponyc
make arch=x86-64 tune=native && make install
