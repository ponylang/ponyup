# How to cut a ponyup release

This document is aimed at members of the team who might be cutting a release of ponyup. It serves as a checklist that can take you through doing a release step-by-step.

## Prerequisites

* You must have commit access to the ponyup repository.
* It would be helpful to have read and write access to the ponylang [cloudsmith](https://cloudsmith.io/) account.

## Releasing

Please note that this document was written with the assumption that you are using a clone of the `ponyup` repo. You have to be using a clone rather than a fork. It is advised to your do this by making a fresh clone of the `ponyup` repo from which you will release.

```bash
git clone git@github.com:ponylang/ponyup.git ponyup-release-clean
cd ponyup-release-clean
```

Before getting started, you will need a number for the version that you will be releasing as well as an agreed upon "golden commit" that will form the basis of the release.

The "golden commit" must be `HEAD` on the `main` branch of this repository. At this time, releasing from any other location is not supported.

For the duration of this document, that we are releasing version is `0.3.1`. Any place you see those values, please substitute your own version.

```bash
git tag release-0.3.1
git push origin release-0.3.1
```

## If something goes wrong

The release process can be restarted at various points in it's lifecycle by pushing specially crafted tags.

## Start a release

As documented above, a release is started by pushing a tag of the form `release-x.y.z`.

## Build artifacts

Each platform job builds a release archive and publishes it to two destinations: the Cloudsmith `ponylang/releases` repository and the GitHub Release at tag `x.y.z`. The GitHub Release itself is created early in this stage with an empty body; the `Announce release` stage fills in the body and marks the release as "latest."

The release process can be manually restarted from here by pushing a tag of the form `x.y.z`. The pushed tag must be on the commit to build the release artifacts from. During the normal process, that commit is the same as the one that `release-x.y.z` was pushed on. Re-pushing `x.y.z` is safe: the GitHub Release is left in place if it already exists, and each platform job re-uploads its archive, replacing any prior copy.

## Announce release

The release process can be manually restarted from here by push a tag of the form `announce-x.y.z`. The tag must be on a commit that is after "Release x.y.z" commit that was generated during the `Start a release` portion of the process.

If you need to restart from here, you will need to pull the latest updates from the ponyup repo as it will have changed and the commit you need to tag will not be available in your copy of the repo with pulling.
