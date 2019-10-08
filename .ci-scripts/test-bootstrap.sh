#!/bin/sh

triple="$(cc -dumpmachine)"
libc="${triple##*-}"

rm -rf \
  /usr/local/bin/ponyc \
  /usr/local/bin/stable \
  /usr/local/lib/x86-64/libpony* \
  /usr/local/include/pony* \
  /usr/local/packages

cat ponyup-init.sh | sh -s -- --prefix=/usr/local

export PATH=$HOME/.pony/ponyup/bin:$PATH
ponyup update nightly --libc=${libc}

make clean
make ssl=0.9.0
