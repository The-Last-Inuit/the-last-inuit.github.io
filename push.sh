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
for f in *.html; do pandoc "$f" -t plain -o "${f%.html}.txt"; done
git add .
git commit -m "update website".
git push -f
