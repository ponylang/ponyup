#!/bin/bash

set -o errexit
set -o nounset

#
# *** You should already be logged in to DockerHub when you run this ***
#

DOCKERFILE_DIR="$(dirname "$0")"

docker build -t "ponylang/ponyup-ci-x86-64-unknown-linux-builder:latest" \
  "${DOCKERFILE_DIR}"
docker push "ponylang/ponyup-ci-x86-64-unknown-linux-builder:latest"
