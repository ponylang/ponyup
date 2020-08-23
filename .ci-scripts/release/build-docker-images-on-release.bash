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

# Pull in shared configuration specific to this repo
base=$(dirname "$0")
# shellcheck source=.ci-scripts/release/config.bash
source "${base}/config.bash"

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${GITHUB_REF}" ]]; then
  echo -e "\e[31mThe release tag needs to be set in GITHUB_REF."
  echo -e "\e[31mThe tag should be in the following GitHub specific form:"
  echo -e "\e[31m    /refs/tags/X.Y.Z"
  echo -e "\e[31mwhere X.Y.Z is the version we are releasing"
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo -e "\e[31mName of this repository needs to be set in GITHUB_REPOSITORY."
  echo -e "\e[31mShould be in the form OWNER/REPO, for example:"
  echo -e "\e[31m     ponylang/ponyup"
  echo -e "\e[31mThis will be used as the docker image name."
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

# no unset variables allowed from here on out
# allow above so we can display nice error messages for expected unset variables
set -o nounset

# We aren't validating TAG is in our x.y.z format but we could.
# For now, TAG validating is left up to the configuration in
# our GitHub workflow
# Tag ref version: "refs/tags/1.0.0"
# Version: "1.0.0"
VERSION="${GITHUB_REF/refs\/tags\//}"

# Build and push :VERSION tag e.g. ponylang/ponyup:0.32.1
DOCKER_TAG=${GITHUB_REPOSITORY}:"${VERSION}"
docker build --pull -t "${DOCKER_TAG}" .
docker push "${DOCKER_TAG}"

# Build and push "release" tag e.g. ponylang/ponyup:release
DOCKER_TAG=${GITHUB_REPOSITORY}:release
docker build --pull -t "${DOCKER_TAG}" .
docker push "${DOCKER_TAG}"
