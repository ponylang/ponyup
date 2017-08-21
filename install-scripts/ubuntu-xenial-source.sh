#!/bin/sh

set -o errexit
set -o nounset

apt-get update
apt-get install -y wget
echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main"
  | tee -a /etc/apt/sources.list
echo "deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main"
  | tee -a /etc/apt/sources.list

cd /tmp
wget -O llvm-snapshot.gpg.key http://apt.llvm.org/llvm-snapshot.gpg.key
apt-key add llvm-snapshot.gpg.key

apt-get update
sudo apt-get install -y \
  build-essential \
  git \
  libncurses5-dev \
  libpcre2-dev \
  libssl-dev \
  llvm-3.9 \
  zlib1g-dev

cd /tmp
git clone https://github.com/ponylang/ponyc
cd ponyc
make -j$(nproc)
make install
