#!/bin/sh

rm -rf \
  /usr/local/bin/ponyc \
  /usr/local/bin/stable \
  /usr/local/lib/x86-64/libpony* \
  /usr/local/include/pony* \
  /usr/local/packages

export PATH=$(pwd)/.pony_test/ponyup/bin:$PATH
make clean
make
