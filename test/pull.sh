#!/bin/bash

source ~/.bash_profile

COMPARE_BRANCH="$2"
COMPARE_REPO="$1"

cd dosomething
$(git fetch --quiet original && git remote add compare git@sniff:$COMPARE_REPO)

files=""
for i in $(git fetch --quiet compare && git diff --diff-filter=ACMR original/dev compare/$COMPARE_BRANCH --name-only)
do
  git checkout compare/$COMPARE_BRANCH -- $i
  files="$files $i"
done

codercs --report=json $files
rm -rf *
git remote remove compare

