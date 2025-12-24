#!/usr/bin/env bash

set -e
zola build
rm -rf ./about
rm -rf ./icon
rm -rf ./img
rm -rf ./js
rm -rf ./posts
mv public/* .
git add .
git commit -m "update website".
git push -f
