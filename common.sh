#!/bin/bash

# Enable strict error checking and exit on error or pipe failure
set -o errexit -o pipefail

# Define a function to print an error message and exit
print() {
    echo "$1" >&2
    exit 1
}

# Get the directory containing this script
dir="$(dirname "$(realpath "$0")")"

# Make sure we have exactly one command-line argument (device type)
[[ $# -eq 1 ]] || print "Expected a single argument (device type)"

# Make sure the BUILD_NUMBER and OUT environment variables are set
[[ -n $BUILD_NUMBER ]] || print "Expected BUILD_NUMBER in the environment"
[[ -n $OUT ]] || print "Expected OUT in the environment"

# Set the scheduling policy of this script to "batch" for better performance
chrt -b -p 0 $$

# Set the paths to the directories containing the keys
COMMON_KEY_DIR=keys/common
PERSISTENT_KEY_DIR=keys/$1
if [ -d $COMMON_KEY_DIR ]; then
    PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
fi

# Set the output directory for the release artifacts
RELEASE_OUT=out/release-$1-$BUILD_NUMBER

# Decrypt the keys in advance for improved performance and modern algorithm support
KEY_DIR=$(mktemp -d /dev/shm/release_keys.XXXXXXXXXX)
trap 'rm -rf \"$KEY_DIR\" && rm -f \"$PWD/$RELEASE_OUT/keys\"' EXIT
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR"
"$dir"/script/decrypt_keys.sh "$KEY_DIR"

# Add the build tools to the PATH
export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"

#!/bin/bash

# Remove any existing release artifacts and create the output directory
rm -rf "$RELEASE_OUT"
mkdir -p "$RELEASE_OUT"

# Unzip the OTA tools into the output directory
unzip "$OUT/otatools.zip" -d "$RELEASE_OUT"
cd "$RELEASE_OUT"

# Create a symbolic link to the keys directory for use with otacerts.zip
ln -s "$KEY_DIR" keys
KEY_DIR=keys

# Add the OTA tools to the PATH
export PATH="$PWD/bin:$PATH"

# Set the device type
DEVICE=$1

# Set the target files name
TARGET_FILES=lineage_$DEVICE-target_files-$BUILD_NUMBER.zip