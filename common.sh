#!/bin/bash

# Common setup shared by the release scripts. Source this, don't execute it.

# Enable strict error checking and exit on error or pipe failure
set -o errexit -o pipefail

# Define a function to print an error message and exit
print_error() {
  echo "$1" >&2
  exit 1
}

# Get the directory containing the scripts
dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Set the scheduling policy of this script to "batch" for better performance
chrt -b -p 0 $$

# Set the path to the directory containing the keys
COMMON_KEY_DIR=~/.android-certs

# Pick the key directory to use for a device, preferring per-device keys in the
# ROM tree over the common ones. Sets ROM_ROOT and PERSISTENT_KEY_DIR.
setup_key_dir() {
  local device=$1

  # Get ROM root directory from OUT
  ROM_ROOT="${OUT%\/out/*}"

  if [ -d "$ROM_ROOT/keys/$device" ]; then
    PERSISTENT_KEY_DIR=$ROM_ROOT/keys/$device
  elif [ -d "$ROM_ROOT/keys/common" ]; then
    PERSISTENT_KEY_DIR=$ROM_ROOT/keys/common
  elif [ -d "$COMMON_KEY_DIR/$device" ]; then
    PERSISTENT_KEY_DIR=$COMMON_KEY_DIR/$device
  else
    PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
  fi
}
