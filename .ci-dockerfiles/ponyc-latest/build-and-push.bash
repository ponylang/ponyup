#!/bin/bash

set -o errexit
set -o nounset

#
# *** You should already be logged in to DockerHub when you run this ***
#

DOCKERFILE_DIR="$(dirname "$0")"

docker build -t "ponylang/ponyup-ci-ponyc-latest:latest" \
  "${DOCKERFILE_DIR}"
docker push "ponylang/ponyup-ci-ponyc-latest:latest"
