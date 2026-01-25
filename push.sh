#!/usr/bin/env bash

set -e
zola build
rm -rf ./about
rm -rf ./img
rm -rf ./js
rm -rf ./posts
rm -rf ./projects
mv public/* .
rm -rf public
git add .
git commit -m "update website".
git push -f
