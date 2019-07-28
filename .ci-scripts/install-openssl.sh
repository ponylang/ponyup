#!/bin/sh

wget https://www.openssl.org/source/openssl-1.1.0.tar.gz \
   && tar xf openssl-1.1.0.tar.gz \
   && cd openssl-1.1.0 \
   && ./config \
   && make \
   && make install \
   && cd .. \
   && rm -rf openssl-1.1.0*
