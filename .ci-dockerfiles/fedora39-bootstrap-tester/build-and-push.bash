#!/bin/bash

set -o errexit
set -o nounset

#
# *** You should already be logged in to GHCR when you run this ***
#

TODAY=$(date +%Y%m%d)
DOCKERFILE_DIR="$(dirname "$0")"
DOCKER_TAG="ghcr.io/ponylang/ponyup-ci-fedora39-bootstrap-tester:${TODAY}"

docker build --pull -t "${DOCKER_TAG}" "${DOCKERFILE_DIR}"
docker push "${DOCKER_TAG}"
