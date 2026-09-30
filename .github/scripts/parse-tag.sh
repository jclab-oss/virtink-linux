#!/bin/bash
# Parses a release tag <path>/<version>[-r<revision>], such as kernel/6.18.54
# or rootfs/alpine/3.24.2-r1, into GitHub Actions outputs:
#
#   dir      the directory to build: <path>/<the longest prefix of <version>
#            that is a directory>, such as kernel/6.18 or rootfs/alpine/3.24
#   version  the version to build, such as 6.18.54
#   tag      the image tag of the release, <version>[-r<revision>]
#   image    the image name, such as kernel or rootfs-alpine
#   tags     the image tags, one per line: <version>[-r<revision>], <version>
#            and the series of dir, such as 6.18.54-r1, 6.18.54 and 6.18
#
# A revision rebuilds the same version, such as after a config change.
set -euo pipefail

tag=$1
path=${tag%/*}
name=${tag##*/}
version=${name%-r*}

if [[ "$tag" != */* || ! "$name" =~ ^[0-9]+(\.[0-9]+)*(-r[0-9]+)?$ ]]; then
    echo "::error::tag '$tag' is not <path>/<version>[-r<revision>]"
    exit 1
fi

series=$version
while [ ! -d "$path/$series" ]; do
    if [[ "$series" != *.* ]]; then
        echo "::error::no directory for tag '$tag' in $path/"
        exit 1
    fi
    series=${series%.*}
done

echo "dir=$path/$series"
echo "version=$version"
echo "tag=$name"
echo "image=${path//\//-}"
echo "tags<<EOF"
printf '%s\n' "$name" "$version" "$series" | uniq
echo "EOF"
