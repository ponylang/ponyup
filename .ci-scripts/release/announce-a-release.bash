#!/bin/bash

# Announces a release after artifacts have been built:
#
# - Publishes release notes to GitHub
# - Announces in the #announce stream of Zulip
# - Adds a note about the release to LWIP
#
# Tools required in the environment that runs this:
#
# - bash
# - changelog-tool
# - curl
# - git
# - jq

set -o errexit

# Pull in shared configuration specific to this repo
base=$(dirname "$0")
source "${base}/config.bash"

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${APPLICATION_NAME}" ]]; then
  echo -e "\e[31mName of the application being announced needs to be set in APPLICATION_NAME."
  echo -e "Exiting.\e[0m"
  exit 1
fi

if [[ -z "${RELEASE_TOKEN}" ]]; then
  echo -e "\e[31mA personal access token needs to be set in RELEASE_TOKEN."
  echo -e "\e[31mIt should not be secrets.GITHUB_TOKEN. It has to be a"
  echo -e "\e[31mpersonal access token otherwise next steps in the release"
  echo -e "\e[31mprocess WILL NOT trigger."
  echo -e "\e[31mPersonal access tokens are in the form:"
  echo -e "\e[31m     TOKEN"
  echo -e "\e[31mfor example:"
  echo -e "\e[31m     1234567890"
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${GITHUB_REF}" ]]; then
  echo -e "\e[31mThe release tag needs to be set in GITHUB_REF."
  echo -e "\e[31mThe tag should be in the following GitHub specific form:"
  echo -e "\e[31m    /refs/tags/announce-X.Y.Z"
  echo -e "\e[31mwhere X.Y.Z is the version we are announcing"
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo -e "\e[31mName of this repository needs to be set in GITHUB_REPOSITORY."
  echo -e "\e[31mShould be in the form OWNER/REPO, for example:"
  echo -e "\e[31m     ponylang/ponyup"
  echo -e "\e[31mExiting.\e[0m"
  exit 1
fi

if [[ -z "${ZULIP_TOKEN}" ]]; then
  echo -e "\e[31mA Zulip access token needs to be set in ZULIP_TOKEN."
  echo -e "Exiting.\e[0m"
  exit 1
fi

# no unset variables allowed from here on out
# allow above so we can display nice error messages for expected unset variables
set -o nounset

# Set up .netrc file with GitHub credentials
git config --global user.name 'Ponylang Main Bot'
git config --global user.email 'ponylang.main@gmail.com'
git config --global push.default simple

PUSH_TO="https://${RELEASE_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

# Extract version from tag reference
# Tag ref version: "refs/tags/announce-1.0.0"
# Version: "1.0.0"
VERSION="${GITHUB_REF/refs\/tags\/announce-/}"

# Prepare release notes
echo -e "\e[34mPreparing to update GitHub release notes...\e[0m"
body=$(changelog-tool get "${VERSION}")

jsontemplate="
{
  \"tag_name\":\$version,
  \"name\":\$version,
  \"body\":\$body
}
"

json=$(jq -n \
--arg version "$VERSION" \
--arg body "$body" \
"${jsontemplate}")

# Upload release notes
echo -e "\e[34mUploading release notes...\e[0m"
result=$(curl -s -X POST "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${RELEASE_TOKEN}" \
  --data "${json}")

rslt_scan=$(echo "${result}" | jq -r '.id')
if [ "$rslt_scan" != null ]; then
  echo -e "\e[34mRelease notes uploaded\e[0m"
else
  echo -e "\e[31mUnable to upload release notes, here's the curl output..."
  echo -e "\e[31m${result}\e[0m"
  exit 1
fi

# Send announcement to Zulip
message="
Version ${VERSION} of ${APPLICATION_NAME} has been released.

See the [release notes](https://github.com/${GITHUB_REPOSITORY}/releases/tag/${VERSION}) for more details.
"

curl -s -X POST https://ponylang.zulipchat.com/api/v1/messages \
  -u ${ZULIP_TOKEN} \
  -d "type=stream" \
  -d "to=announce" \
  -d "topic=${APPLICATION_NAME}" \
  -d "content=${message}"

# Update Last Week in Pony
echo -e "\e[34mAdding release to Last Week in Pony...\e[0m"

result=$(curl https://api.github.com/repos/ponylang/ponylang-website/issues?labels=last-week-in-pony)

lwip_url=$(echo "${result}" | jq -r '.[].url')
if [ "$lwip_url" != "" ]; then
  body="
Version ${VERSION} of ${APPLICATION_NAME} has been released.

See the [release notes](https://github.com/${GITHUB_REPOSITORY}/releases/tag/${VERSION}) for more details.
"

  jsontemplate="
  {
    \"body\":\$body
  }
  "

  json=$(jq -n \
  --arg body "$body" \
  "${jsontemplate}")

  result=$(curl -s -X POST "$lwip_url/comments" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "${RELEASE_TOKEN}" \
    --data "${json}")

  rslt_scan=$(echo "${result}" | jq -r '.id')
  if [ "$rslt_scan" != null ]; then
    echo -e "\e[34mRelease notice posted to LWIP\e[0m"
  else
    echo -e "\e[31mUnable to post to LWIP, here's the curl output..."
    echo -e "\e[31m${result}\e[0m"
  fi
else
  echo -e "\e[31mUnable to post to Last Week in Pony."
  echo -e "Can't find the issue.\e[0m"
fi

# delete announce-VERSION tag
echo -e "\e[34mDeleting no longer needed remote tag announce-${VERSION}\e[0m"
git push --delete ${PUSH_TO} "announce-${VERSION}"
