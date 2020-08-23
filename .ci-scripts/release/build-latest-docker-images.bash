#!/bin/bash

# *** You should already be logged in to DockerHub when you run this ***
#
# Builds docker latest docker images.
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

# Build and push "latest" tag e.g. ponylang/ponyup:latest
DOCKER_TAG=${GITHUB_REPOSITORY}:latest
docker build --pull -t "${DOCKER_TAG}" .
docker push "${DOCKER_TAG}"
