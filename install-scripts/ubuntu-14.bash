#! /bin/bash

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
  libssl-dev

pushd /tmp
  wget "ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2"
  tar -xjvf pcre2-10.21.tar.bz2
  cd pcre2-10.21 && ./configure --prefix=/usr && make && make install && cd -
  # TODO check for previous llvm install
  wget "http://releases.llvm.org/3.9.1/clang+llvm-3.9.1-x86_64-linux-gnu-ubuntu-14.04.tar.xz"
  tar -xvf clang+llvm*
  cd clang+llvm* && sudo cp -R * /usr/local && cd -
popd

git clone https://github.com/ponylang/ponyc
cd ponyc
make arch=x86-64 tune=native && make install

ponyc examples/helloworld
./helloworld
