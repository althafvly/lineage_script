#!/bin/bash

# Enable strict error checking and exit on error or pipe failure
set -o errexit -o pipefail

# Define a function to print an error message and exit
print_error() {
  echo "$1" >&2
  exit 1
}

# Get the directory containing this script
dir="$(dirname "$(realpath "$0")")"

# Set the device type
if [ -z "$TARGET_PRODUCT" ]; then
  # Make sure we have exactly one command-line argument (device type)
  [[ $# -eq 1 ]] || print_error "Expected a single argument (device type)"
  DEVICE=$1
else
  DEVICE=$(echo "$TARGET_PRODUCT" | cut -d '_' -f 2-)
fi

# Make sure the OUT environment variable set.
[[ -n $OUT ]] || print_error "Expected OUT in the environment"

# Get ROM root directory from OUT
ROM_ROOT="${OUT%\/out/*}"

# Set the scheduling policy of this script to "batch" for better performance
chrt -b -p 0 $$

# Set the paths to the directories containing the keys
OLD_COMMON_KEY_DIR=$ROM_ROOT/keys/common
OLD_PERSISTENT_KEY_DIR=$ROM_ROOT/keys/$DEVICE
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

# Decrypt the keys in advance for improved performance and modern algorithm support
# Copy the keys to a temporary directory and remove it when the script exits.
KEY_DIR="$OUT/keys"
if [ ! -d "$KEY_DIR" ]; then
  cp -r "$PERSISTENT_KEY_DIR" "$KEY_DIR"
  "$dir"/crypt_keys.sh -d "$KEY_DIR"
fi

TARGET_DIR=$OUT/obj/PACKAGING/target_files_intermediates

if [ "$(find $TARGET_DIR/ -name *-target_files*.zip -print -quit)" ]; then
  CONFIG_FILE="vendor/lineage/config/version.mk"
  if [ ! -f "$CONFIG_FILE" ]; then
    # If version.mk doesn't exist, use common.mk
    CONFIG_FILE="vendor/lineage/config/common.mk"
  fi

  # Extract version information
  PRODUCT_VERSION_MAJOR=$(grep -oP 'PRODUCT_VERSION_MAJOR = \K.*' "$CONFIG_FILE")
  PRODUCT_VERSION_MINOR=$(grep -oP 'PRODUCT_VERSION_MINOR = \K.*' "$CONFIG_FILE")
  LINEAGE_VER=$PRODUCT_VERSION_MAJOR.$PRODUCT_VERSION_MINOR

  SIGN_TARGETS=()

  if [ "$PRODUCT_VERSION_MAJOR" -ge 19 ]; then
    for PACKAGE in $(cat "$dir/apex.list"); do
      if [ -f "$KEY_DIR/$PACKAGE.pem" ]; then
        SIGN_TARGETS+=(--extra_apks "$PACKAGE.apex=$KEY_DIR/$PACKAGE"
          --extra_apex_payload_key "$PACKAGE.apex=$KEY_DIR/$PACKAGE.pem")
      elif [ -f "$KEY_DIR/avb.pem" ]; then
        SIGN_TARGETS+=(--extra_apks "$PACKAGE.apex=$KEY_DIR/releasekey"
          --extra_apex_payload_key "$PACKAGE.apex=$KEY_DIR/avb.pem")
      else
        echo "APEX modules will signed using public payload key"
        SIGN_TARGETS+=(--extra_apks "$PACKAGE.apex=$KEY_DIR/releasekey"
          --extra_apex_payload_key "$PACKAGE.apex=$ROM_ROOT/external/avb/test/data/testkey_rsa4096.pem")
      fi
    done

    for PACKAGE in $(cat "$dir/apexapk.list"); do
      SIGN_TARGETS+=(--extra_apks "$PACKAGE.apk=$KEY_DIR/releasekey")
    done
  fi

  # Set the target files name
  BUILD_DATE=$(date -u +%Y%m%d)
  TARGET_FILES=lineage_$DEVICE-target_files-$BUILD_DATE.zip
  sign_target_files_apks -o -d "$KEY_DIR" "${SIGN_TARGETS[@]}" \
    $TARGET_DIR/*-target_files*.zip "$OUT/$TARGET_FILES"

  ota_from_target_files -k "$KEY_DIR/releasekey" "$OUT/$TARGET_FILES" \
    "$OUT/lineage-$LINEAGE_VER-$BUILD_DATE-ota_package-$DEVICE-signed.zip" || exit 1

  FASTBOOT_PACKAGE="lineage-$LINEAGE_VER-$BUILD_DATE-fastboot_package-$DEVICE.zip"
  IMAGES=("recovery" "boot" "vendor_boot" "dtbo")

  img_from_target_files "$OUT/$TARGET_FILES" "$OUT/$FASTBOOT_PACKAGE"

  for i in "${!IMAGES[@]}"; do
    if unzip -l "$OUT/$FASTBOOT_PACKAGE" | grep -q "${IMAGES[i]}.img"; then
      unzip -o -j -q "$OUT/$FASTBOOT_PACKAGE" "${IMAGES[i]}.img" -d "$OUT"
      mv "$OUT/${IMAGES[i]}.img" "$OUT/lineage-$LINEAGE_VER-$BUILD_DATE-${IMAGES[i]}-$DEVICE.img"
    fi
  done
else
  print_error "Unable to find target_files"
fi
