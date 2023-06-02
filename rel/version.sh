#!/usr/bin/env bash

# if we are on a tag, use that exact version
# if we are on a release branch, use version from the branch name
# otherwise find the latest tag and add 1 to the patch number
# if no tag exist use 0.0.0

# with argument -t display type of the version:
# exact tag - release
# release branch - qa
# otherwise - dev

set -o pipefail

if [[ "$1" == "-t" ]]; then
    release_type() {
        read && echo release
    }
    qa_type() {
        echo qa
    }
    dev_type() {
        echo dev
    }
else
    release_type() {
        read TAG && echo ${TAG#v}
    }
    qa_type() {
        echo $1
    }
    dev_type() {
        git describe --abbrev=0 2>/dev/null | awk -F. -vOFS=. '{sub(/^v/,"",$1);$3=$3+1;print}' \
            || echo "0.0.0"
    }
fi


git describe --exact-match 2>/dev/null | release_type && exit

# could be simply
# git for-each-ref --count 1 --points-at HEAD --format='%(refname)' '**/release/*'
# but ancient centos 6 box has git 1.8 that doesn't support --points-at and the pattern
HEAD=$(git rev-parse HEAD)
git for-each-ref --format='%(objectname) %(refname)' refs/remotes refs/heads | \
    while read REF BRANCH; do
        if [[ $REF == $HEAD && $BRANCH =~ .*/release/v?(.*) ]]; then
            qa_type ${BASH_REMATCH[1]}
            exit 1
        fi
    done || exit 0

dev_type
