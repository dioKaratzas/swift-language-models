#!/bin/bash
# Works out the version a release tags, and reads or sets the version the package reports, `UserAgent.packageVersion`
# in Sources/LanguageModels/UserAgent.swift. Nothing reads the tag at build time, so a release's pull request sets the
# package's version to the tag its merge creates. A release tags the version after the latest `X.Y.Z` tag:
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
#   release-version.sh get <file>            Prints the package's version that the Swift file sets.
#   release-version.sh set <file> <version>  Sets the package's version in the Swift file.
set -euo pipefail

semver='^[0-9]+\.[0-9]+\.[0-9]+$'
declaration='^( *package static let packageVersion = ")([^"]*)(".*)$'

fail() {
    echo "release-version.sh: $*" >&2
    exit 1
}

# Prints the version that the Swift file's single packageVersion declaration sets.
get_version() {
    local file=$1 count version
    count=$(grep -cE "$declaration" "$file" || true)
    [ "$count" = 1 ] || fail "$file declares packageVersion $count times, not once."
    version=$(sed -nE "s/$declaration/\2/p" "$file")
    [[ $version =~ $semver ]] || fail "$file sets packageVersion to \"$version\", not an X.Y.Z version."
    echo "$version"
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
get)
    [ $# -eq 2 ] || fail "usage: release-version.sh get <file>"
    get_version "$2"
    ;;
set)
    [ $# -eq 3 ] || fail "usage: release-version.sh set <file> <version>"
    file=$2
    version=$3
    [[ $version =~ $semver ]] || fail "\"$version\" isn't an X.Y.Z version."
    get_version "$file" > /dev/null
    sed -i.bak -E "s/$declaration/\1$version\3/" "$file"
    rm "$file.bak"
    [ "$(get_version "$file")" = "$version" ] || fail "couldn't set packageVersion in $file."
    ;;
*)
    fail "usage: release-version.sh bump | next <bump> | get <file> | set <file> <version>"
    ;;
esac
