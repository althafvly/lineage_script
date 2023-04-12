#!/bin/bash

dir="$(dirname "$(realpath "$0")")"

build_id=$(grep -o 'BUILD_ID=.*' build/make/core/build_id.mk | cut -d "=" -f 2 | cut -c 1 | tr '[:upper:]' '[:lower:]')

if [[ "$build_id" == [rst] ]]; then
    "$dir"/release_"$build_id".sh "$@"
else
    "$dir"/release_r.sh "$@"
fi
