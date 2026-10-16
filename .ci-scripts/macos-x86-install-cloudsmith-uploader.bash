#!/bin/bash

set -o errexit

curl -sL -o /tmp/cloudsmith-uploader.tar.gz \
  "https://github.com/ponylang/cloudsmith-uploader/releases/latest/download/cloudsmith-uploader-x86-64-apple-darwin.tar.gz"
tar -xzf /tmp/cloudsmith-uploader.tar.gz -C /tmp
cp /tmp/*/bin/cloudsmith-uploader /tmp/cloudsmith-uploader
