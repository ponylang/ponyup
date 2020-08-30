#!/bin/bash

set -o errexit
set -o nounset

#
# *** You should already be logged in to DockerHub when you run this ***
#

TODAY=$(date +%Y%m%d)
DOCKERFILE_DIR="$(dirname "$0")"

docker build --pull \
  -t "ponylang/ponyup-ci-ubuntu18.04-bootstrap-tester:${TODAY}" \
  "${DOCKERFILE_DIR}"
docker push "ponylang/ponyup-ci-ubuntu18.04-bootstrap-tester:${TODAY}"
