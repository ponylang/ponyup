FROM ubuntu:24.04

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates \
     clang \
     curl \
     git \
     libssl-dev \
     lsb-release \
     make \
  && rm -rf /var/lib/apt/lists/*

RUN git config --global --add safe.directory /__w/ponyup/ponyup
