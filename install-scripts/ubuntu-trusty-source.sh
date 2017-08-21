#!/bin/sh

set -o errexit
set -o nounset

apt-get update
apt-get install -y wget
echo "deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-3.9 main" \
  | tee -a /etc/apt/sources.list
echo "deb-src http://apt.llvm.org/trusty/ llvm-toolchain-trusty-3.9 main\n" \
  | tee -a /etc/apt/sources.list

cd /tmp
wget -O llvm-snapshot.gpg.key http://apt.llvm.org/llvm-snapshot.gpg.key
apt-key add llvm-snapshot.gpg.key

apt-get update
apt-get install -y \
  build-essential \
  git \
  libncurses5-dev \
  libssl-dev \
  llvm-3.9 \
  zlib1g-dev

cd /tmp
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2
tar xjvf pcre2-10.21.tar.bz2
cd pcre2-10.21
./configure --prefix=/usr
make
make install

cd /tmp
git clone https://github.com/ponylang/ponyc.git
cd ponyc
make -j$(nproc)
make install
