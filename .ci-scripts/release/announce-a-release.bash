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
  echo -e "\e[31m    /refs/tags/announce-X.Y.Z"
  echo -e "\e[31mwhere X.Y.Z is the version we are announcing"
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

if [[ -z "${ZULIP_TOKEN}" ]]; then
  echo -e "\e[31mA Zulip access token needs to be set in ZULIP_TOKEN. Exiting."
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
# Tag ref version: "announce-1.0.0"
# Version: "1.0.0"
VERSION="${GITHUB_REF/refs\/tags\/announce-/}"

# Prepare release notes
echo -e "\e[34mPreparing to update GitHub release notes..."
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
echo -e "\e[34mUploading release notes..."
result=$(curl -X POST "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" \
  --data "${json}")

rslt_scan=$(echo "${result}" | jq -r '.id')
if [ "$rslt_scan" != null ]; then
  echo -e "\e[34mRelease notes uploaded"
else
  echo -e "\e[31mUnable to upload release notes, here's the curl output..."
  echo -e "\e[31m${result}"
  exit 1
fi

# Send announcement to Zulip
message="
Version ${VERSION} of ponyup has been released.

See the [release notes](https://github.com/${GITHUB_REPOSITORY}/releases/tag/${VERSION}) for more details.
"

curl -X POST https://ponylang.zulipchat.com/api/v1/messages \
  -u ${ZULIP_TOKEN} \
  -d "type=stream" \
  -d "to=announce" \
  -d "topic=ponyup" \
  -d "content=${message}"

# Update Last Week in Pony
echo -e "\e[34mAdding release to Last Week in Pony..."

result=$(curl https://api.github.com/repos/ponylang/ponylang-website/issues?labels=last-week-in-pony)

lwip_url=$(echo "${result}" | jq -r '.[].url')
if [ "$lwip_url" != "" ]; then
  body="
Version ${VERSION} of ponyup has been released.

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

  result=$(curl -X POST "$lwip_url/comments" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" \
    --data "${json}")

  rslt_scan=$(echo "${result}" | jq -r '.id')
  if [ "$rslt_scan" != null ]; then
    echo -e "\e[34mRelease notice posted to LWIP"
  else
    echo -e "\e[31mUnable to post to LWIP, here's the curl output..."
    echo -e "\e[31m${result}"
  fi
else
  echo -e "\e[31mUnable to post to Last Week in Pony. Can't find the issue."
fi

# delete announce-VERSION tag
echo -e "\e[34mDeleting no longer needed remote tag announce-${VERSION}"
git push --delete origin "announce-${VERSION}"
