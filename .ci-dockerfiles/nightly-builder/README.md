# Overview

This docker image is used to build the `ponyup` nightly releases. It includes
the latest ponyc compiler available.

# Build image

```bash
docker build -t ponylang/ponyup-ci-nightly-builder:latest .
```

# Run image to test

Will get you a bash shell in the image to try cloning Pony into where you can test a build to make sure everything will work before pushing:

```bash
docker run --name ponyup-ci-nightly-builder-latest --rm -i -t ponylang/ponyup-ci-nightly-builder:latest bash
```

# Push to dockerhub

You'll need credentials for the ponylang dockerhub account. Talk to @jemc or @seantallen for access

```bash
docker push ponylang/ponyup-ci-nightly-builder:latest
```
