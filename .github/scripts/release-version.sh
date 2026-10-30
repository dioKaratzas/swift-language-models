#!/bin/bash
# Works out the version a release tags: the version after the latest `X.Y.Z` tag.
#
#   patch  0.1.0 to 0.1.1
#   minor  0.1.0 to 0.2.0
#   major  0.1.0 to 0.2.0 before 1.0, and 1.2.3 to 2.0.0 after it; 1.0.0 itself is tagged by hand.
#
# Usage:
#   release-version.sh bump                  Reads a pull request's labels, one a line, and prints the release they
#                                            ask for: major over minor over patch, or nothing without a release label.
#   release-version.sh next <bump>           Reads tag names, one a line, and prints `last=<tag>` and
#                                            `next=<version>` for $GITHUB_OUTPUT. Both are empty before the first
#                                            `X.Y.Z` tag: the first release is tagged by hand.
set -euo pipefail

semver='^[0-9]+\.[0-9]+\.[0-9]+$'

fail() {
    echo "release-version.sh: $*" >&2
    exit 1
}

case ${1-} in
bump)
    labels=$(cat)
    for level in major minor patch; do
        if grep -qxF "release:$level" <<< "$labels"; then
            echo "$level"
            break
        fi
    done
    ;;
next)
    bump=${2-}
    case $bump in
    patch | minor | major) ;;
    *) fail "the release is \"$bump\", not patch, minor or major." ;;
    esac
    last=$({ grep -E "$semver" || true; } | sort -V | tail -n 1)
    next=
    if [ -n "$last" ]; then
        IFS=. read -r major minor patch <<< "$last"
        major=$((10#$major)) minor=$((10#$minor)) patch=$((10#$patch))
        case $bump in
        major)
            if [ "$major" -eq 0 ]; then minor=$((minor + 1)); else major=$((major + 1)) minor=0; fi
            patch=0
            ;;
        minor) minor=$((minor + 1)) patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        esac
        next="$major.$minor.$patch"
    fi
    echo "last=$last"
    echo "next=$next"
    ;;
*)
    fail "usage: release-version.sh bump | next <bump>"
    ;;
esac
