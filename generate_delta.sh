#!/bin/bash

# Enable strict error checking and exit on error or pipe failure
set -o errexit -o pipefail

# Function to print an error message and exit the script with an error code
print_error() {
    echo "$1" >&2
    exit 1
}

# Get the directory containing this script
dir="$(dirname "$(realpath "$0")")"

# Check if the script was called with three arguments (device name, old target zip, and new target zip)
[[ $# -eq 3 ]] || print_error "expected 3 arguments (device, old_target.zip, new_target.zip)"

# Set the scheduling policy for the current process to 'batch'
chrt -b -p 0 $$

# Get ROM root directory from OUT
ROM_ROOT="${OUT%\/out/*}"

# Set the paths to the directories containing the keys
OLD_COMMON_KEY_DIR=$ROM_ROOT/keys/common
OLD_PERSISTENT_KEY_DIR=$ROM_ROOT/keys/$1
# Use common/device keys dir if it exists
if [ -d "$OLD_PERSISTENT_KEY_DIR" ]; then
    PERSISTENT_KEY_DIR=$OLD_PERSISTENT_KEY_DIR
elif [ -d "$OLD_COMMON_KEY_DIR" ]; then
    PERSISTENT_KEY_DIR=$OLD_COMMON_KEY_DIR
else
    COMMON_KEY_DIR=~/.android-certs
    PERSISTENT_KEY_DIR=~/.android-certs/$DEVICE
    # Use common keys if device dir doesnt exists
    if [ ! -d "$PERSISTENT_KEY_DIR" ]; then
        PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
    fi
fi

# Save the device name, old target zip, and new target zip arguments in variables
DEVICE=$1
OLD_TARGET_ZIP=$(realpath "$2")
NEW_TARGET_ZIP=$(realpath "$3")
NEW_TARGET_DIR=${NEW_TARGET_ZIP%/*}

# Decrypt the keys in advance for improved performance and modern algorithm support
# Copy the keys to a temporary directory and remove it when the script exits.
KEY_DIR="$NEW_TARGET_DIR/keys"
cp -r "$PERSISTENT_KEY_DIR" "$KEY_DIR"
"$dir"/crypt_keys.sh -d "$KEY_DIR"

# Extract the build numbers from the old and new target zips
BUILD_NUMBER=$(basename "${OLD_TARGET_ZIP%%.*}" | cut -d'-' -f3)-$(basename "${NEW_TARGET_ZIP%%.*}" | cut -d'-' -f3)

# Create the incremental OTA package
ota_from_target_files "${EXTRA_OTA[@]}" -k "$KEY_DIR/releasekey" \
    -i "$OLD_TARGET_ZIP" "$NEW_TARGET_ZIP" "$NEW_TARGET_DIR/lineage_$DEVICE-incremental-$BUILD_NUMBER.zip"
