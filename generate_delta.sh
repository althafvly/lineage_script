#!/bin/bash

# Set bash options to stop the script if an error occurs and to treat unset variables as errors
set -o errexit -o nounset -o pipefail

# Function to print an error message and exit the script with an error code
user_error() {
    echo "$1" >&2
    exit 1
}

# Get the directory of the script and save it in the $dir variable
dir="$(dirname "$(realpath "$0")")"

# Check if the script was called with three arguments (device name, old target zip, and new target zip)
[[ $# -eq 3 ]] || user_error "expected 3 arguments (device, old_target.zip, new_target.zip)"

# Set the scheduling policy for the current process to 'batch'
chrt -b -p 0 $$

# Set the common key directory and persistent key directory based on the device name argument
COMMON_KEY_DIR=keys/common
PERSISTENT_KEY_DIR=keys/$1
if [ -d COMMON_KEY_DIR ]; then
    PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
fi

# Save the device name, old target zip, and new target zip arguments in variables
DEVICE=$1
OLDZIP=$2
NEWZIP=$3
OTADIR=${NEWZIP%/*}

# Create a temporary directory for the decrypted keys and set a trap to delete it when the script exits
KEY_DIR=$(mktemp -d --tmpdir delta_keys.XXXXXXXXXX)
trap 'rm -rf \"$KEY_DIR\"' EXIT

# Copy the keys from the persistent key directory to the temporary key directory and decrypt them
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR"
"$dir"/script/decrypt_keys.sh "$KEY_DIR"

# Set the path to the build tools and path tools directories
export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"

# Extract the build numbers from the old and new target zips
OLD_BUILDNO=$(basename "$OLDZIP" | sed -e s/[^0-9]//g)
NEW_BUILDNO=$(basename "$NEWZIP" | sed -e s/[^0-9]//g)

# Create the incremental OTA package
ota_from_target_files "${EXTRA_OTA[@]}" -k "$KEY_DIR/releasekey" \
    -i "$OLDZIP" "$NEWZIP" "$OTADIR/lineage_$DEVICE-incremental-$OLD_BUILDNO-$NEW_BUILDNO.zip"
