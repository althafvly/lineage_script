#!/bin/bash

# Get the directory where the script is located
dir="$(dirname "$(realpath "$0")")"

# Extract the build ID from the build/make/core/build_id.mk file
build_id=$(grep -o 'BUILD_ID=.*' "$dir"/../build/make/core/build_id.mk | cut -d "=" -f 2 | cut -c 1 | tr '[:upper:]' '[:lower:]')

# If the build ID is one of 'r', 's', or 't', run the appropriate release script for that build
if [[ "$build_id" == [rst] ]]; then
    "$dir"/release_"$build_id".sh "$@"
else
    # If the build ID is not one of 'r', 's', or 't', default to running the release_r.sh script
    "$dir"/release_r.sh "$@"
fi
