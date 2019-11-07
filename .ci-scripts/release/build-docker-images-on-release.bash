#!/bin/bash

# *** You should already be logged in to DockerHub when you run this ***
#
# Builds docker release images with two tags:
#
# - release
# - X.Y.Z for example 0.32.1
#
# Tools required in the environment that runs this:
#
# - bash
# - docker

set -o errexit
set -o nounset

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${GITHUB_REF}" ]]; then
  echo -e "\e[31mThe release tag needs to be set in GITHUB_REF."
  echo -e "\e[31mThe tag should be in the following GitHub specific form:"
  echo -e "\e[31m    /refs/tags/X.Y.Z"
  echo -e "\e[31mwhere X.Y.Z is the version we are releasing"
  echo -e "\e[31mExiting."
  exit 1
fi

# We aren't validating TAG is in our x.y.z format but we could.
# For now, TAG validating is left up to the configuration in
# our GitHub workflow
VERSION="${GITHUB_REF/refs\/tags\//}"

# Build and push :VERSION tag e.g. ponyup:0.32.1
DOCKER_TAG=ponylang/ponyup:"${VERSION}"
docker build --file=.dockerhub/alpine/Dockerfile -t "${DOCKER_TAG}" .
docker push "${DOCKER_TAG}"

# Build and push "release" tag e.g. ponyup:release
DOCKER_TAG=ponylang/ponyup:release
docker build --file=.dockerhub/alpine/Dockerfile -t "${DOCKER_TAG}" .
docker push "${DOCKER_TAG}"
