FROM ubuntu:20.04

# Keep annoying tzdata prompt from coming up
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates \
     clang \
     curl \
     git \
     libssl-dev \
     lsb-core \
     make \
  && rm -rf /var/lib/apt/lists/*
