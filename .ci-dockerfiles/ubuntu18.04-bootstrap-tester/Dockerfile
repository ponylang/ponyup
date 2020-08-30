FROM ubuntu:18.04

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates \
     clang \
     curl \
     git \
     libssl-dev \
     make \
  && rm -rf /var/lib/apt/lists/*
