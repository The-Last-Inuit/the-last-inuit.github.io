#!/usr/bin/env bash

set -e
mix still.compile
git add .
git commit -m "update website".
git push -f
