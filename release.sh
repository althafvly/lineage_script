#!/bin/bash

# Load the shared setup (strict mode, print_error, dir, key directory helpers)
source "$(dirname "$(realpath "$0")")/common.sh"
source "$dir/cert_lists.sh"

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

# Set ROM_ROOT and the directory containing the keys
setup_key_dir "$DEVICE"

# Decrypt the keys in advance
KEY_DIR="$OUT/keys"
if [ ! -d "$KEY_DIR" ]; then
  "$dir"/crypt_keys.sh -d "$PERSISTENT_KEY_DIR" "$KEY_DIR"
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
    for PACKAGE in $APEX_CERTS; do
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

    for PACKAGE in $APEXAPK_CERTS; do
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
  IMAGES=("boot" "dtbo" "init_boot" "recovery" "super_empty" "vbmeta" "vendor_boot" "vendor_kernel_boot")

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
