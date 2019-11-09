ARG FROM_TAG=release
FROM ponylang/shared-docker-ci-x86-64-unknown-linux-builder:${FROM_TAG}

RUN apk update \
  && apk upgrade \
  && apk upgrade curl \
  && apk add --update libressl-dev
