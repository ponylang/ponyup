#!/bin/bash

# Triggers the running of the announce a release process
#
# - Creates announce-X.Y.Z tag and pushes to remote repo
#
# This script should be set up in CI to only run after all build artifact
# creation tasks have successfully run. It is built to be a separate script
# and ci step so that multi-artifacts could in theory be created and uploaded
# before a release is announced.
#
# Tools required in the environment that runs this:
#
# - bash
# - git

set -o errexit
set -o nounset

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${GITHUB_ACTOR}" ]]; then
  echo -e "\e[31mName of the user to make changes to repo as need to be set in GITHUB_ACTOR. Exiting."
  exit 1
fi

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo -e "\e[31mA personal access token needs to be set in GITHUB_TOKEN. Exiting."
  exit 1
fi

if [[ -z "${GITHUB_REF}" ]]; then
  echo -e "\e[31mA tag for the version we are announcing needs to be set in GITHUB_REF."
  echo -e "\e[31mThe tag should be in the following GitHub specific form:"
  echo -e "\e[31m    /refs/tags/X.Y.Z"
  echo -e "\e[31mwhere X.Y.Z is the version we are announcing"
  echo -e "\e[31mExiting."
  exit 1
fi

# Set up .netrc file with GitHub credentials
cat <<- EOF > $HOME/.netrc
      machine github.com
      login $GITHUB_ACTOR
      password $GITHUB_TOKEN
      machine api.github.com
      login $GITHUB_ACTOR
      password $GITHUB_TOKEN
EOF

chmod 600 $HOME/.netrc

git config --global user.name 'Ponylang Main Bot'
git config --global user.email 'ponylang.main@gmail.com'
git config --global push.default simple

# Extract version from tag reference
# Tag ref version: "refs/tags/1.0.0"
# Version: "1.0.0"
VERSION="${GITHUB_REF/refs\/tags\//}"

# tag for announcement
echo -e "\e[34mTagging to kick off release announcement"
git tag "announce-${VERSION}"

# push tag
echo -e "\e[34mPushing announce-${VERSION} tag"
git push origin "announce-${VERSION}"
