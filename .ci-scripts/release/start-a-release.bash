#!/bin/bash

# Starts the release process by:
#
# - Getting latest changes on master
# - Updating version in
#   - VERSION
#   - CHANGELOG.md
# - Pushing updated VERSION and CHANGELOG.md back to master
# - Pushing tag to kick off building artifacts
# - Adding a new "unreleased" section to CHANGELOG
# - Pushing updated CHANGELOG back to master
#
# Tools required in the environment that runs this:
#
# - bash
# - changelog-tool
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
  echo -e "\e[31mThe release tag needs to be set in GITHUB_REF."
  echo -e "\e[31mThe tag should be in the following GitHub specific form:"
  echo -e "\e[31m    /refs/tags/release-X.Y.Z"
  echo -e "\e[31mwhere X.Y.Z is the version we are releasing"
  echo -e "\e[31mExiting."
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo -e "\e[31mName of this repository needs to be set in GITHUB_REPOSITORY."
  echo -e "\e[31mShould be in the form OWNER/REPO, for example:"
  echo -e "\e[31m     ponylang/ponyup"
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
# Tag ref version: "refs/tags/release-1.0.0"
# Version: "1.0.0"
VERSION="${GITHUB_REF/refs\/tags\/release-/}"

### this doesn't account for master changing commit, assumes we are HEAD
# or can otherwise push without issue. that shouldl error out without issue.
# leaving us to restart from a different HEAD commit
git checkout master
git pull

# update VERSION
echo -e "\e[34mUpdating VERSION to ${VERSION}"
echo "${VERSION}" > VERSION

# version the changelog
echo -e "\e[34mUpdating CHANGELOG.md for release"
changelog-tool release "${VERSION}" -e

# commit CHANGELOG and VERSION updates
echo -e "\e[34mCommiting VERSION and CHANGELOG.md changes"
git add CHANGELOG.md VERSION
git commit -m "${VERSION} release"

# tag release
echo -e "\e[34mTagging for release to kick off building artifacts"
git tag "${VERSION}"

# push to release to remote
echo -e "\e[34mPushing commited changes back to master"
git push origin master
echo -e "\e[34mPushing ${VERSION} tag"
git push origin "${VERSION}"

# pull again, just in case, odds of this being needed are really slim
git pull

# update CHANGELOG for new entries
echo -e "\e[34mAdding new 'unreleased' section to CHANGELOG.md"
changelog-tool unreleased -e

# commit changelog and push to master
echo -e "\e[34mCommiting CHANGELOG.md change"
git add CHANGELOG.md
git commit -m "Add unreleased section to CHANGELOG post ${VERSION} release [skip ci]"

echo -e "\e[34mPushing CHANGELOG.md"
git push origin master

# delete release-VERSION tag
echo -e "\e[34mDeleting no longer needed remote tag release-${VERSION}"
git push --delete origin "release-${VERSION}"
