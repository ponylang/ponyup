#!/bin/sh

set -o errexit
set -o nounset

apt-get update
apt-get install -y software-properties-common
add-apt-repository ppa:ubuntu-toolchain-r/test
apt-get update
apt-get install -y \
  apt-transport-https \
  build-essential \
  git \
  libncurses5-dev \
  libssl-dev \
  libpcre2-dev \
  zlib1g-dev

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys "8756C4F765C9AC3CB6B85D62379CE192D401AB61"
echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main"\
  | tee -a /etc/apt/sources.list
apt-get update
apt-get -V install ponyc
