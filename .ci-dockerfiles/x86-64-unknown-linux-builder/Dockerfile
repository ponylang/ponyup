FROM ponylang/shared-docker-ci-x86-64-unknown-linux-builder:release

RUN apk update \
  && apk upgrade \
  && apk upgrade curl \
  && apk add --update libressl-dev
