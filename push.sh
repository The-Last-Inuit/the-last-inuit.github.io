#!/usr/bin/env bash

set -e
git add .
mv _site/* .
git commit -m "update website".
git push -f
