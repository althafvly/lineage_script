#!/bin/bash

# Load the shared setup (strict mode, print_error, dir, key directory helpers)
source "$(dirname "$(realpath "$0")")/common.sh"

# Check if the script was called with three arguments (device name, old target zip, new target zip and output zip)
[[ $# -eq 4 ]] || print_error "expected 4 arguments (device, old_target.zip, new_target.zip, output-incremental.zip)"

DEVICE=$1

# Set ROM_ROOT and the directory containing the keys
setup_key_dir "$DEVICE"

# Save the device name, old target zip, and new target zip arguments in variables
OLD_TARGET_ZIP=$(realpath "$2")
NEW_TARGET_ZIP=$(realpath "$3")
OUTPUT_ZIP=$(realpath "$4")
NEW_TARGET_DIR=${NEW_TARGET_ZIP%/*}

# Decrypt the keys in advance for improved performance and modern algorithm support
# Copy the keys to a temporary directory and remove it when the script exits.
KEY_DIR="$NEW_TARGET_DIR/keys"
"$dir"/crypt_keys.sh -d "$PERSISTENT_KEY_DIR" "$KEY_DIR"

# Create the incremental OTA package
ota_from_target_files -k "$KEY_DIR/releasekey" \
  -i "$OLD_TARGET_ZIP" "$NEW_TARGET_ZIP" "$OUTPUT_ZIP"
