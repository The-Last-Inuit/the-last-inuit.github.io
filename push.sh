#!/usr/bin/env bash

set -e
zola build
rm -rf ./about
rm -rf ./icon
rm -rf ./img
rm -rf ./js
rm -rf ./posts
rm -rf ./projects
mv public/* .
rm -rf public
find . -type f -name '*.html' -print0 |
  while IFS= read -r -d '' f; do
    pandoc "$f" -t plain -o "${f%.html}.txt"
  done
git add .
git commit -m "update website".
git push -f
