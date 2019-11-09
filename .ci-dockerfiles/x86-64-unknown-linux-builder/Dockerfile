FROM ponylang/ponyc:release-alpine

RUN apk update \
  && apk upgrade \
  && apk upgrade curl \
  && apk add --update \
  py-pip \
  libressl-dev \
  curl \
  bash \
  && pip install cloudsmith-cli
